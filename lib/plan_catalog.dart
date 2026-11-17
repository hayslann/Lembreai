/// Planos comerciais planejados. Nenhuma compra e ativada nesta versao.
/// NUNCA liberar direitos premium com uma preferencia gravada no celular.
class LembrePlan {
  final String id;
  final String name;
  final int activeLimit;
  final String monthlyPrice;
  final bool available;
  const LembrePlan(this.id,this.name,this.activeLimit,this.monthlyPrice,
      {this.available=false});
}
const plans = <LembrePlan>[
  LembrePlan('free','Gratuito',10,'Grátis',available:true),
  LembrePlan('plus','Plus',200,'R\$ 12,90/mês'),
  LembrePlan('pro','Pro',300,'R\$ 17,90/mês'),
  LembrePlan('max','Max',500,'R\$ 27,90/mês'),
];
const int freeActiveReminderLimit=10;
bool canAddFreeReminders(int active,int toAdd) =>
    active>=0 && toAdd>=0 && active+toAdd<=freeActiveReminderLimit;
