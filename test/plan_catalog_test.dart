import 'package:flutter_test/flutter_test.dart';
import '../lib/plan_catalog.dart';

void main(){
  test('10 lembretes gratuitos e sem ativacao de compra local',(){
    expect(plans.first.id,'free');
    expect(plans.first.activeLimit,10);
    expect(plans.first.available,true);
    expect(canAddFreeReminders(9,1),true);
    expect(canAddFreeReminders(10,1),false);
    expect(canAddFreeReminders(8,3),false);
  });
  test('limites comerciais nao sao ativados na beta',(){
    expect(plans.where((plan)=>!plan.available).length,3);
    expect(plans[1].activeLimit,200);
    expect(plans[2].activeLimit,300);
    expect(plans[3].activeLimit,500);
  });
}
