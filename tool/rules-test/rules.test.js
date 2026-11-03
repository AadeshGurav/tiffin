// firestore.rules against the real Firestore emulator. The rules are the
// security boundary (ADR 0005), and the Dart fake can't evaluate them.
//
//   cd tool/rules-test && npm install && npm test

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  runTransaction,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-tiffin',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

/** Seed documents with rules off. */
async function seed(docs) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [path, data] of Object.entries(docs)) {
      await setDoc(doc(db, path), data);
    }
  });
}

const phone = (uid) => env.authenticatedContext(uid).firestore();
// A person signed in with a real provider (Google, email), not a phone's anonymous identity.
const person = (uid) =>
  env.authenticatedContext(uid, { firebase: { sign_in_provider: 'password' } }).firestore();
const anonymous = (uid) =>
  env.authenticatedContext(uid, { firebase: { sign_in_provider: 'anonymous' } }).firestore();
const approved = (role) => ({ name: role, status: 'approved', role });
const member = { name: 'Asha', balances: { lunch: 2, breakfast: 0, brunch: 0 } };

describe('joining', () => {
  test('a phone may ask to join as a pending scanner, as itself only', async () => {
    const db = phone('p1');
    await assertSucceeds(setDoc(doc(db, 'canteens/c1/devices/p1'),
        { name: 'Gate', status: 'pending', role: 'scanner' }));
    await assertFails(setDoc(doc(db, 'canteens/c1/devices/p2'),
        { name: 'Gate', status: 'pending', role: 'scanner' }));
  });

  test('a phone cannot approve itself', async () => {
    const db = phone('p1');
    await assertFails(setDoc(doc(db, 'canteens/c1/devices/p1'),
        { name: 'Gate', status: 'approved', role: 'admin' }));
  });

  test('only an admin phone approves others', async () => {
    await seed({
      'canteens/c1/devices/admin': approved('admin'),
      'canteens/c1/devices/counter': approved('counter'),
      'canteens/c1/devices/new': { name: 'New', status: 'pending', role: 'scanner' },
    });
    await assertFails(updateDoc(doc(phone('counter'), 'canteens/c1/devices/new'),
        { status: 'approved', role: 'counter' }));
    await assertSucceeds(updateDoc(doc(phone('admin'), 'canteens/c1/devices/new'),
        { status: 'approved', role: 'counter' }));
  });
});

describe('data access by phone role', () => {
  beforeEach(() => seed({
    'canteens/c1/devices/admin': approved('admin'),
    'canteens/c1/devices/counter': approved('counter'),
    'canteens/c1/devices/scanner': approved('scanner'),
    'canteens/c1/devices/pending': { name: 'P', status: 'pending', role: 'scanner' },
    'canteens/c1/devices/removed': { name: 'R', status: 'removed', role: 'admin' },
    'canteens/c1/members/m1': member,
  }));

  test('pending and removed phones read nothing', async () => {
    await assertFails(getDoc(doc(phone('pending'), 'canteens/c1/members/m1')));
    await assertFails(getDoc(doc(phone('removed'), 'canteens/c1/members/m1')));
  });

  test('a scanner phone reads members but cannot edit them', async () => {
    const db = phone('scanner');
    await assertSucceeds(getDoc(doc(db, 'canteens/c1/members/m1')));
    await assertFails(updateDoc(doc(db, 'canteens/c1/members/m1'), { name: 'Changed' }));
  });

  test('a scanner phone may only lower a balance (a scan), never raise it', async () => {
    const db = phone('scanner');
    await assertSucceeds(updateDoc(doc(db, 'canteens/c1/members/m1'),
        { balances: { lunch: 1, breakfast: 0, brunch: 0 } }));
    await assertFails(updateDoc(doc(db, 'canteens/c1/members/m1'),
        { balances: { lunch: 9, breakfast: 0, brunch: 0 } }));
  });

  test('a counter phone can top up but not refund', async () => {
    const db = phone('counter');
    await assertSucceeds(setDoc(doc(db, 'canteens/c1/topups/t1'), { memberId: 'm1', amount: 40 }));
    await assertFails(setDoc(doc(db, 'canteens/c1/refunds/r1'), { memberId: 'm1' }));
  });

  test('every approved phone reads offline accounts; only admins edit them', async () => {
    await seed({ 'canteens/c1/users/u1': { username: 'a', passwordHash: 'x' } });
    // Every approved phone needs them to check a sign-in offline.
    await assertSucceeds(getDoc(doc(phone('scanner'), 'canteens/c1/users/u1')));
    await assertFails(updateDoc(doc(phone('counter'), 'canteens/c1/users/u1'), { role: 'admin' }));
  });
});

describe('the one-scan-per-meal lock', () => {
  beforeEach(() => seed({
    'canteens/c1/devices/a': approved('scanner'),
    'canteens/c1/devices/b': approved('scanner'),
    'canteens/c1/members/m1': member,
  }));

  const scan = (db) => {
    const batch = writeBatch(db);
    batch.set(doc(db, 'canteens/c1/scans/m1_2026-10-17_lunch'),
        { memberId: 'm1', reversed: false, mealType: 'lunch' });
    batch.update(doc(db, 'canteens/c1/members/m1'),
        { balances: { lunch: 1, breakfast: 0, brunch: 0 } });
    return batch.commit();
  };

  test('the second phone to sync the same meal is refused, decrement and all', async () => {
    await assertSucceeds(scan(phone('a')));
    await assertFails(scan(phone('b')));
    let lunch;
    await env.withSecurityRulesDisabled(async (ctx) => {
      lunch = (await getDoc(doc(ctx.firestore(), 'canteens/c1/members/m1'))).data().balances.lunch;
    });
    // Only the first batch landed.
    if (lunch !== 1) throw new Error(`balance is ${lunch}, expected 1`);
  });

  test('a staff phone cannot write a scan already marked reversed', async () => {
    await assertFails(setDoc(doc(phone('a'), 'canteens/c1/scans/x_r1'), { reversed: true }));
  });
});

describe('online accounts', () => {
  beforeEach(() => seed({
    'canteens/c1/onlineUsers/on': { email: 'a@b.c', role: 'counter', status: 'active' },
    'canteens/c1/onlineUsers/off': { email: 'd@e.f', role: 'admin', status: 'inactive' },
    'canteens/c1/members/m1': member,
  }));

  test('an active online account gets its role', async () => {
    await assertSucceeds(getDoc(doc(phone('on'), 'canteens/c1/members/m1')));
    await assertFails(setDoc(doc(phone('on'), 'canteens/c1/refunds/r1'), {}));
  });

  test('a turned-off online account gets nothing', async () => {
    await assertFails(getDoc(doc(phone('off'), 'canteens/c1/members/m1')));
  });

  test('an online account cannot promote itself', async () => {
    await assertFails(updateDoc(doc(phone('on'), 'canteens/c1/onlineUsers/on'), { role: 'admin' }));
  });
});

describe('canteens', () => {
  const create = (db, uid, code = 'ABCD2345') => runTransaction(db, async (tx) => {
    const root = doc(db, `canteens/${code}`);
    if ((await tx.get(root)).exists()) throw new Error('taken');
    tx.set(root, { name: 'Gate canteen', ownerUid: uid });
    tx.set(doc(db, `canteens/${code}/onlineUsers/${uid}`),
        { email: 'a@b.c', role: 'admin', status: 'active' });
  });

  test('a real identity creates a canteen and becomes its admin', async () => {
    await assertSucceeds(create(person('owner'), 'owner'));
    await assertSucceeds(getDoc(doc(person('owner'), 'canteens/ABCD2345/members/none')));
  });

  test('an anonymous phone cannot create a canteen', async () => {
    await assertFails(create(anonymous('p'), 'p'));
  });

  test('nobody can overwrite or take over an existing canteen code', async () => {
    await seed({ 'canteens/ABCD2345': { name: 'x', ownerUid: 'owner' } });
    await assertFails(setDoc(doc(person('late'), 'canteens/ABCD2345'),
        { name: 'mine', ownerUid: 'late' }));
    await assertFails(setDoc(doc(person('late'), 'canteens/ABCD2345/onlineUsers/late'),
        { email: 'x@y.z', role: 'admin', status: 'active' }));
  });

  test('a canteen can be read by its code but never listed', async () => {
    await seed({ 'canteens/ABCD2345': { name: 'x', ownerUid: 'owner' } });
    await assertSucceeds(getDoc(doc(anonymous('p'), 'canteens/ABCD2345')));
    await assertFails(getDocs(collection(anonymous('p'), 'canteens')));
  });

  test('the creator can restore their own admin row, nobody else can', async () => {
    await seed({
      'canteens/ABCD2345': { name: 'x', ownerUid: 'owner' },
      'canteens/ABCD2345/onlineUsers/owner': { email: 'a@b.c', role: 'scanner', status: 'pending' },
    });
    const row = { email: 'a@b.c', role: 'admin', status: 'active' };
    await assertSucceeds(setDoc(doc(person('owner'), 'canteens/ABCD2345/onlineUsers/owner'), row));
    await assertFails(setDoc(doc(person('late'), 'canteens/ABCD2345/onlineUsers/late'), row));
  });

  test('a role in one canteen grants nothing in another', async () => {
    await seed({
      'canteens/c1/devices/admin': approved('admin'),
      'canteens/c2/members/m1': member,
    });
    await assertFails(getDoc(doc(phone('admin'), 'canteens/c2/members/m1')));
  });

  test('a real identity asks to join as a pending scanner, not as admin', async () => {
    await seed({ 'canteens/c1/members/m1': member });
    const db = person('new');
    await assertSucceeds(setDoc(doc(db, 'canteens/c1/onlineUsers/new'),
        { email: 'n@b.c', role: 'scanner', status: 'pending' }));
    await assertFails(setDoc(doc(db, 'canteens/c1/onlineUsers/new'),
        { email: 'n@b.c', role: 'admin', status: 'active' }));
    await assertFails(getDoc(doc(db, 'canteens/c1/members/m1')));
  });
});
