# firestore.rules tests

`firestore.rules` is the security boundary once every phone talks to Firestore
directly (ADR 0005), and the Dart fake can't evaluate real rules. These run the
actual rules file on the Firestore emulator.

```sh
cd tool/rules-test
npm install
npm test
```

Needs Java 17 or newer. `firebase-tools` is pinned to 13.x because 14+ refuses
Java older than 21; bump it once the build machine has JDK 21.
