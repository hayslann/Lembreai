// Política de recompensa proposta. Somente callbacks AdMob SSV verificados
// e conta de usuário autenticada podem gerar créditos reais.
export const REWARD_TYPE='extra_reminder_slot';
export const REWARD_UNITS_PER_VIEW=1;
export const MAX_REWARDED_VIEWS_PER_DAY=3;
export const REWARD_VALIDITY_HOURS=24;
export function validateRewardReceipt(r) {
  return !!r && r.verifiedByGoogle===true && typeof r.uid==='string' &&
    /^[a-zA-Z0-9:_-]{5,150}$/.test(r.uid) &&
    typeof r.transactionId==='string' &&
    /^[a-zA-Z0-9:_-]{10,180}$/.test(r.transactionId);
}
