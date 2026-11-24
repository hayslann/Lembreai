const KEY_URL='https://www.gstatic.com/admob/reward/verifier-keys.json';
let keyCache={expiresAt:0,keys:new Map()};

function decodeBase64(value) {
  const normalized=value.replace(/-/g,'+').replace(/_/g,'/');
  const padded=normalized+'='.repeat((4-normalized.length%4)%4);
  return Uint8Array.from(atob(padded),c=>c.charCodeAt(0));
}

function derEcdsaToRaw(signature) {
  // AdMob supplies ASN.1 DER; WebCrypto ECDSA expects fixed-width r||s.
  const b=signature;
  if(b.length<8||b[0]!==0x30)throw new Error('invalid DER signature');
  let offset=2;
  if(b[1]&0x80)offset=2+(b[1]&0x7f);
  if(b[offset++]!==0x02)throw new Error('invalid DER r');
  const rLen=b[offset++];let r=b.slice(offset,offset+rLen);offset+=rLen;
  if(b[offset++]!==0x02)throw new Error('invalid DER s');
  const sLen=b[offset++];let s=b.slice(offset,offset+sLen);
  while(r.length>32&&r[0]===0)r=r.slice(1);
  while(s.length>32&&s[0]===0)s=s.slice(1);
  if(r.length>32||s.length>32)throw new Error('invalid DER integer size');
  const raw=new Uint8Array(64);
  raw.set(r,32-r.length);raw.set(s,64-s.length);
  return raw;
}

async function publicKeys() {
  if(Date.now()<keyCache.expiresAt&&keyCache.keys.size)return keyCache.keys;
  const response=await fetch(KEY_URL,{signal:AbortSignal.timeout(8000)});
  if(!response.ok)throw new Error('AdMob public keys unavailable');
  const body=await response.json();
  const keys=new Map();
  for(const item of body.keys||[]) {
    if(!Number.isSafeInteger(item.keyId)||typeof item.base64!=='string')continue;
    try {
      const key=await crypto.subtle.importKey('spki',decodeBase64(item.base64),
        {name:'ECDSA',namedCurve:'P-256'},false,['verify']);
      keys.set(String(item.keyId),key);
    } catch (_) {}
  }
  if(!keys.size)throw new Error('AdMob public keys invalid');
  keyCache={keys,expiresAt:Date.now()+6*60*60*1000};
  return keys;
}

/** Verify the exact original query bytes; AdMob requires keeping parameter order. */
export async function verifyAdMobCallback(request) {
  const url=new URL(request.url);
  const rawQuery=url.search.slice(1);
  const marker='&signature=';
  const signatureIndex=rawQuery.indexOf(marker);
  if(signatureIndex<0||!rawQuery.endsWith('key_id='+url.searchParams.get('key_id')))
    return null;
  const signedBytes=new TextEncoder().encode(rawQuery.slice(0,signatureIndex));
  const keyId=url.searchParams.get('key_id');
  const signatureValue=url.searchParams.get('signature');
  if(!keyId||!signatureValue||!/^[0-9]{1,16}$/.test(keyId))return null;
  const key=(await publicKeys()).get(keyId);
  if(!key)return null;
  try {
    const valid=await crypto.subtle.verify({name:'ECDSA',hash:'SHA-256'},key,
      derEcdsaToRaw(decodeBase64(signatureValue)),signedBytes);
    if(!valid)return null;
  } catch (_) {return null;}
  const timestamp=Number(url.searchParams.get('timestamp'));
  const transactionId=url.searchParams.get('transaction_id')||'';
  const uid=url.searchParams.get('user_id')||'';
  const customData=url.searchParams.get('custom_data')||'';
  const adUnit=url.searchParams.get('ad_unit')||'';
  if(!Number.isSafeInteger(timestamp)||Math.abs(Date.now()-timestamp)>24*60*60*1000||
      !/^[A-Za-z0-9:_-]{5,150}$/.test(uid)||
      !/^[A-Za-z0-9_-]{32,100}$/.test(customData)||
      // O callback de teste do painel pode usar um transaction_id sintético
      // mais curto ou com separadores. A assinatura ECDSA já foi verificada
      // antes deste ponto; o valor continua sendo obrigatório e nunca autoriza
      // recompensa sem uma sessão válida no D1.
      !/^[A-Za-z0-9:_-]{1,128}$/.test(transactionId)||
      !/^[0-9]{1,24}$/.test(adUnit))return null;
  return {uid,customData,transactionId,adUnit,timestamp};
}

export async function applyAdMobReward(db,receipt,expectedAdUnit='') {
  if(!receipt||!db)return false;
  if(expectedAdUnit&&receipt.adUnit!==expectedAdUnit)return false;
  const now=new Date().toISOString();
  const user=await db.prepare("SELECT uid FROM users WHERE uid=? AND account_status='active'")
    .bind(receipt.uid).first();
  if(!user)return false;
  const session=await db.prepare(`SELECT custom_data FROM reward_sessions
    WHERE custom_data=? AND user_uid=? AND status='pending'
      AND datetime(expires_at)>CURRENT_TIMESTAMP`).bind(receipt.customData,receipt.uid).first();
  if(!session)return false;
  await db.batch([
    db.prepare(`UPDATE reward_sessions SET status='credited',transaction_id=?,completed_at=?
      WHERE custom_data=? AND user_uid=? AND status='pending'
        AND datetime(expires_at)>CURRENT_TIMESTAMP AND transaction_id IS NULL`)
      .bind(receipt.transactionId,now,receipt.customData,receipt.uid),
    db.prepare(`INSERT OR IGNORE INTO credit_ledger(user_uid,event_type,delta,reference_id,actor,expires_at)
      SELECT user_uid,'admob_reward',1,'admob:'||transaction_id,'admob_ssv',datetime('now','+24 hours')
      FROM reward_sessions WHERE custom_data=? AND user_uid=?
        AND status='credited' AND transaction_id=?`)
      .bind(receipt.customData,receipt.uid,receipt.transactionId),
    db.prepare(`UPDATE users SET credit_balance=(SELECT COALESCE(SUM(delta),0)
      FROM credit_ledger WHERE user_uid=? AND
        (expires_at IS NULL OR datetime(expires_at)>CURRENT_TIMESTAMP)) WHERE uid=?`)
      .bind(receipt.uid,receipt.uid),
  ]);
  return true;
}
