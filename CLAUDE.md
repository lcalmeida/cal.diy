# Project conventions

## Horário comercial e fuso horário

Decisões coletadas em entrevista com o time (2026-09-01), relevantes para
qualquer feature que dependa de "horário comercial" (ex: o aviso de reserva
fora do expediente em `packages/features/bookings/lib/isOutsideBusinessHours.ts`).

- **Definição de horário comercial**: não é um valor fixo e global para o
  produto todo. É **configurável**, no mínimo por usuário (o time também
  mencionou nível de organização/equipe). Um intervalo único hardcoded
  (ex: "Seg-Sex 9h-18h") é apenas um placeholder e **não** deve ser tratado
  como regra de negócio definitiva.
- **Fuso horário de avaliação**: o horário comercial deve ser avaliado no
  **fuso do host/organizador** do evento — não no fuso de quem está vendo a
  tela (booker/attendee) nem em um fuso fixo da empresa.
- **Variação por dia da semana**: os dias/horários podem ser diferentes
  entre si (ex: sexta encerrando mais cedo, fim de semana fechado) — isso
  também é parte do que precisa ser configurável, não um padrão fixo único.
- **Feriados**: não foi confirmado se feriados devem ser considerados; não
  assumir isso sem confirmar.
- **Status da implementação atual**: o mecanismo de configuração (por
  usuário e/ou por org/equipe) **ainda não existe** no produto — é só uma
  intenção registrada aqui. Antes de trocar o valor fixo por algo dinâmico,
  será necessário desenhar onde/como essa configuração é armazenada
  (possivelmente reaproveitando o conceito de Availability Schedules, a
  confirmar) e como ela chega até o client (booker e dashboard).

**Como aplicar**: ao evoluir `isOutsideBusinessHours` (ou qualquer feature
nova que dependa de horário comercial), não hardcode um novo intervalo fixo
sem antes confirmar com o usuário se a configurabilidade por usuário/org já
está disponível para consumir. Se ainda não estiver, é esperado continuar
com um placeholder, mas deixe isso explícito no código/PR.
