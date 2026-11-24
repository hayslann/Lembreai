import 'package:flutter_test/flutter_test.dart';
import '../lib/plan_catalog.dart';

void main(){
  test('beta pessoal sem limite de lembretes ou créditos',(){
    expect(plans.first.id,'free');
    expect(plans.first.activeLimit,10);
    expect(plans.first.available,true);
    expect(canAddFreeReminders(9,1),true);
    expect(personalBetaUnlimited,true);
    expect(canAddFreeReminders(10,1),true);
    expect(canAddFreeReminders(8,3),true);
    expect(canAddFreeReminders(10000,500),true);
    expect(reminderCreditsNeeded(500,20),0);
    expect(canAddFreeReminders(-1,1),false);
    expect(reminderCreditsNeeded(9,3,unlimited:false),2);
    expect(reminderCreditsNeeded(15,3,unlimited:false),3);
  });
  test('limites comerciais nao sao ativados na beta',(){
    expect(plans.where((plan)=>!plan.available).length,3);
    expect(plans[1].activeLimit,200);
    expect(plans[2].activeLimit,300);
    expect(plans[3].activeLimit,500);
  });
}
