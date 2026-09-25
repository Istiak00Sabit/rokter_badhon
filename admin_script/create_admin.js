const { initializeApp, cert } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");

const serviceAccount = require("./serviceAccountKey.json");


initializeApp({
  credential: cert(serviceAccount),
});


const auth = getAuth();
const db = getFirestore();


async function createAdmin() {

  const phone = "01700000000";
  const password = "Admin@12345";

  // Same format as Flutter AuthIdentity
  const internalEmail = `p${phone}@auth.rokterbadhon.internal`;


  try {

    // 1. Create Firebase Auth User
    const authUser = await auth.createUser({
      email: internalEmail,
      password: password,
      emailVerified: true,
    });


    console.log("Firebase Auth Created");
    console.log("UID:", authUser.uid);


    // 2. Create Firestore user document
    const userRef = db.collection("users").doc();

    await userRef.set({

      name: "System Admin",

      phone: phone,

      email: null,

      blood_group: null,

      profession: "Admin",

      address: null,

      photo_url: null,


      access_role: "developer_admin",

      active: true,

      login_enabled: true,

      preferred_language: "bn",


      created_at: Timestamp.now(),

      created_by: "system",

      updated_at: Timestamp.now(),

      updated_by: "system"

    });


    console.log("User document created:", userRef.id);



    // 3. Create auth_links
    await db.collection("auth_links").doc(authUser.uid).set({

      user_id: userRef.id,

      active: true,

      created_at: Timestamp.now(),

      created_by: "system"

    });


    console.log("Auth link created");

    console.log("DONE ✅");


  } catch(error){

    console.error(error);

  }

}


createAdmin();