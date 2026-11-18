import test from 'node:test';
import assert from 'node:assert/strict';
import {validateRewardReceipt,MAX_REWARDED_VIEWS_PER_DAY,REWARD_UNITS_PER_VIEW} from './reward_policy.mjs';
test('nunca concede recompensa sem verificacao Google SSV',()=>{
 const req={uid:'user12345',transactionId:'transaction-12345'};
 assert.equal(validateRewardReceipt(req),false);
 assert.equal(validateRewardReceipt({...req,verifiedByGoogle:false}),false);
 assert.equal(validateRewardReceipt({...req,verifiedByGoogle:true}),true);
});
test('recompensas so podem ser temporarias e limitadas',()=>{
 assert.equal(MAX_REWARDED_VIEWS_PER_DAY,3);
 assert.equal(REWARD_UNITS_PER_VIEW,1);
});
