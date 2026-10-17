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
  doc,
  getDoc,
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
const approved = (role) => ({ name: role, status: 'approved', role });
const member = { name: 'Asha', balances: { lunch: 2, breakfast: 0, brunch: 0 } };

describe('joining', () => {
  test('a phone may ask to join as a pending scanner, as itself only', async () => {
    const db = phone('p1');
    await assertSucceeds(setDoc(doc(db, 'devices/p1'),
        { name: 'Gate', status: 'pending', role: 'scanner' }));
    await assertFails(setDoc(doc(db, 'devices/p2'),
        { name: 'Gate', status: 'pending', role: 'scanner' }));
  });

  test('a phone cannot approve itself', async () => {
    const db = phone('p1');
    await assertFails(setDoc(doc(db, 'devices/p1'),
        { name: 'Gate', status: 'approved', role: 'admin' }));
  });

  test('the first phone claims a fresh project as its admin phone', async () => {
    const db = phone('owner');
    await assertSucceeds(runTransaction(db, async (tx) => {
      const owner = await tx.get(doc(db, 'meta/owner'));
      if (owner.exists()) throw new Error('taken');
      tx.set(doc(db, 'meta/owner'), { uid: 'owner' });
      tx.set(doc(db, 'devices/owner'), { name: 'Office', status: 'approved', role: 'admin' });
    }));
  });

  test('nobody can claim a project that already has an owner', async () => {
    await seed({ 'meta/owner': { uid: 'owner' } });
    const db = phone('late');
    const batch = writeBatch(db);
    batch.set(doc(db, 'meta/owner'), { uid: 'late' });
    batch.set(doc(db, 'devices/late'), { name: 'x', status: 'approved', role: 'admin' });
    await assertFails(batch.commit());
  });

  test('only an admin phone approves others', async () => {
    await seed({
      'devices/admin': approved('admin'),
      'devices/counter': approved('counter'),
      'devices/new': { name: 'New', status: 'pending', role: 'scanner' },
    });
    await assertFails(updateDoc(doc(phone('counter'), 'devices/new'),
        { status: 'approved', role: 'counter' }));
    await assertSucceeds(updateDoc(doc(phone('admin'), 'devices/new'),
        { status: 'approved', role: 'counter' }));
  });
});

describe('data access by phone role', () => {
  beforeEach(() => seed({
    'devices/admin': approved('admin'),
    'devices/counter': approved('counter'),
    'devices/scanner': approved('scanner'),
    'devices/pending': { name: 'P', status: 'pending', role: 'scanner' },
    'devices/removed': { name: 'R', status: 'removed', role: 'admin' },
    'members/m1': member,
  }));

  test('pending and removed phones read nothing', async () => {
    await assertFails(getDoc(doc(phone('pending'), 'members/m1')));
    await assertFails(getDoc(doc(phone('removed'), 'members/m1')));
  });

  test('a scanner phone reads members but cannot edit them', async () => {
    const db = phone('scanner');
    await assertSucceeds(getDoc(doc(db, 'members/m1')));
    await assertFails(updateDoc(doc(db, 'members/m1'), { name: 'Changed' }));
  });

  test('a scanner phone may only lower a balance (a scan), never raise it', async () => {
    const db = phone('scanner');
    await assertSucceeds(updateDoc(doc(db, 'members/m1'),
        { balances: { lunch: 1, breakfast: 0, brunch: 0 } }));
    await assertFails(updateDoc(doc(db, 'members/m1'),
        { balances: { lunch: 9, breakfast: 0, brunch: 0 } }));
  });

  test('a counter phone can top up but not refund', async () => {
    const db = phone('counter');
    await assertSucceeds(setDoc(doc(db, 'topups/t1'), { memberId: 'm1', amount: 40 }));
    await assertFails(setDoc(doc(db, 'refunds/r1'), { memberId: 'm1' }));
  });

  test('every approved phone reads offline accounts; only admins edit them', async () => {
    await seed({ 'users/u1': { username: 'a', passwordHash: 'x' } });
    // Every approved phone needs them to check a sign-in offline.
    await assertSucceeds(getDoc(doc(phone('scanner'), 'users/u1')));
    await assertFails(updateDoc(doc(phone('counter'), 'users/u1'), { role: 'admin' }));
  });
});

describe('the one-scan-per-meal lock', () => {
  beforeEach(() => seed({
    'devices/a': approved('scanner'),
    'devices/b': approved('scanner'),
    'members/m1': member,
  }));

  const scan = (db) => {
    const batch = writeBatch(db);
    batch.set(doc(db, 'scans/m1_2026-10-17_lunch'),
        { memberId: 'm1', reversed: false, mealType: 'lunch' });
    batch.update(doc(db, 'members/m1'),
        { balances: { lunch: 1, breakfast: 0, brunch: 0 } });
    return batch.commit();
  };

  test('the second phone to sync the same meal is refused, decrement and all', async () => {
    await assertSucceeds(scan(phone('a')));
    await assertFails(scan(phone('b')));
    let lunch;
    await env.withSecurityRulesDisabled(async (ctx) => {
      lunch = (await getDoc(doc(ctx.firestore(), 'members/m1'))).data().balances.lunch;
    });
    // Only the first batch landed.
    if (lunch !== 1) throw new Error(`balance is ${lunch}, expected 1`);
  });

  test('a staff phone cannot write a scan already marked reversed', async () => {
    await assertFails(setDoc(doc(phone('a'), 'scans/x_r1'), { reversed: true }));
  });
});

describe('online accounts', () => {
  beforeEach(() => seed({
    'onlineUsers/on': { email: 'a@b.c', role: 'counter', status: 'active' },
    'onlineUsers/off': { email: 'd@e.f', role: 'admin', status: 'inactive' },
    'members/m1': member,
  }));

  test('an active online account gets its role', async () => {
    await assertSucceeds(getDoc(doc(phone('on'), 'members/m1')));
    await assertFails(setDoc(doc(phone('on'), 'refunds/r1'), {}));
  });

  test('a turned-off online account gets nothing', async () => {
    await assertFails(getDoc(doc(phone('off'), 'members/m1')));
  });

  test('an online account cannot promote itself', async () => {
    await assertFails(updateDoc(doc(phone('on'), 'onlineUsers/on'), { role: 'admin' }));
  });
});
