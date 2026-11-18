const FIREBASE_LOOKUP='https://identitytoolkit.googleapis.com/v1/accounts:lookup';

/** Validates Firebase ID tokens through Google's Identity Toolkit service. */
export async function verifyFirebaseUser(request,env) {
  const header=request.headers.get('Authorization')||'';
  const match=header.match(/^Bearer\s+([A-Za-z0-9._~-]{20,5000})$/i);
  if(!match || !env.FIREBASE_WEB_API_KEY)return null;
  try {
    const response=await fetch(FIREBASE_LOOKUP+
      '?key='+encodeURIComponent(env.FIREBASE_WEB_API_KEY),{
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify({idToken:match[1]}),
        signal:AbortSignal.timeout(8000),
      });
    if(!response.ok)return null;
    const payload=await response.json();
    const user=Array.isArray(payload.users)?payload.users[0]:null;
    if(!user || typeof user.localId!=='string' ||
      !/^[A-Za-z0-9:_-]{5,150}$/.test(user.localId))return null;
    return {
      uid:user.localId,
      email:typeof user.email==='string'?user.email.slice(0,254):null,
      emailVerified:user.emailVerified===true,
    };
  } catch (_) {return null;}
}

export async function upsertFirebaseUser(db,user) {
  if(!db || !user?.uid)return;
  await db.prepare(`INSERT INTO users(uid,email,last_active_at,account_status)
    VALUES(?,?,CURRENT_TIMESTAMP,'active')
    ON CONFLICT(uid) DO UPDATE SET email=excluded.email,
      last_active_at=CURRENT_TIMESTAMP`)
    .bind(user.uid,user.email||null).run();
}
