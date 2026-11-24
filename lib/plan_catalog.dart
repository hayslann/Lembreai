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
// Beta pessoal: sem cobrança; limites de segurança da API permanecem.
const bool personalBetaUnlimited = true;
const int freeActiveReminderLimit=10;
int reminderCreditsNeeded(int active, int toAdd, {bool unlimited = personalBetaUnlimited}) {
  if (active < 0 || toAdd < 0) throw ArgumentError('Quantidade inválida');
  if (unlimited) return 0;
  final slots = freeActiveReminderLimit - active;
  final freeSlots = slots > 0 ? slots : 0;
  return toAdd > freeSlots ? toAdd - freeSlots : 0;
}
bool canAddFreeReminders(int active,int toAdd) =>
    active>=0 && toAdd>=0 && reminderCreditsNeeded(active,toAdd)==0;
