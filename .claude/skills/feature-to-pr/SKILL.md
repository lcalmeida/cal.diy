# Feature to PR

Leva uma tarefa descrita em linguagem natural (feature, fix ou chore neste
repositório) do zero até um Pull Request aberto: sempre entrevista o usuário
sobre o procedimento antes de tocar em código, consulta os padrões do
projeto, implementa, testa e abre o PR sozinho ao final.

Use esta skill sempre que o usuário descrever algo para implementar neste
repositório (cal.diy) — não apenas quando a tarefa parecer ambígua. Não é
para revisão de código isolada (`/code-review`), nem para só rodar/testar o
app sem mudar nada (skill `run`).

## Regra de ouro

**Sempre entrevistar antes de escrever qualquer código**, mesmo que a tarefa
pareça óbvia. Uma implementação "óbvia" de cabeça costuma esconder uma
decisão de produto (ex: "horário comercial" não é um valor fixo — depende de
config por usuário/org e do fuso do host, algo que só a entrevista revelou).
Pular a entrevista é o erro mais caro desta skill.

## Fase 1 — Entrevistar (sempre, antes de qualquer exploração de código)

Use `AskUserQuestion` para levantar, no mínimo:

1. **Escopo funcional exato** — onde no produto isso deve aparecer (página
   pública de booking, dashboard, ambos?), e o que exatamente conta como
   "feito".
2. **Regras de negócio implícitas** — todo substantivo vago na tarefa
   ("horário comercial", "resumo", "aviso") provavelmente esconde uma
   decisão: é fixo ou configurável? por usuário, por org, por evento? em
   qual fuso horário é avaliado? Pergunte antes de assumir um valor.
3. **Como validar** — que testes fazem sentido (unitário puro, e2e
   Playwright, verificação visual manual) e se há um teste específico que o
   usuário já tem em mente.
4. **Se a resposta implica uma decisão de arquitetura que ainda não existe no
   produto** (ex: "configurável por org" mas não há mecanismo de config
   ainda), não implemente a configurabilidade do zero por conta própria —
   confirme explicitamente se é para: (a) construir o mecanismo de config
   agora, (b) manter um placeholder documentado, ou (c) só registrar a
   intenção (ex: em `CLAUDE.md`) para depois.

Registre decisões de negócio não triviais em `CLAUDE.md` (criar a seção se
não existir), do jeito que foi feito para "Horário comercial e fuso
horário". Isso evita reabrir a mesma entrevista em tarefas futuras — mas não
dispensa entrevistar de novo se a tarefa tocar uma área ainda não coberta.

## Fase 2 — Consultar padrões do projeto

Antes de escrever código, sempre:

- Ler `CLAUDE.md` na raiz do repo (se existir) — trata como instrução que
  sobrepõe comportamento padrão.
- Procurar código já existente que resolve algo parecido (outro botão de
  copiar, outro Alert de aviso, outro hook) e reaproveitar componentes/hooks
  em vez de reinventar. Ex: `useCopy` para clipboard, `Alert`
  (`@calcom/ui/components/alert`) para avisos, `Badge` para indicadores
  inline.
- Confirmar onde lógica pura deve morar (ex: `packages/features/bookings/lib/`)
  versus componentes de UI (`apps/web/modules/.../components/`).
- Conferir se a feature precisa de tradução: toda string visível ao usuário
  precisa de chave em `packages/i18n/locales/en/common.json` **e**
  `packages/i18n/locales/pt-BR/common.json` — nunca só um dos dois.
- Se a tarefa mexe com data/hora, lembrar que fuso horário é quase sempre
  uma decisão de produto (de quem? host, viewer, org?) — não assumir.

Se uma sub-agent Explore ajudar a mapear onde mexer, use-a — mas a decisão
de design continua sendo sua, não dela.

## Fase 3 — Implementar

- Extraia lógica de negócio pura (sem React/DOM) para um arquivo dedicado e
  testável, mesmo que o call site pareça simples — foi assim que
  `isOutsideBusinessHours.ts` e `buildBookingSummaryText.ts` ficaram
  fáceis de testar isoladamente.
- Ao hardcodar um valor que a entrevista revelou como "deveria ser
  configurável, mas o mecanismo não existe ainda", deixe isso **explícito**
  em comentário no código (referenciando `CLAUDE.md` quando aplicável) — não
  finja que é definitivo.
- Rode `npx tsc --noEmit -p apps/web/tsconfig.json` e filtre pelos arquivos
  alterados. Se aparecerem erros, confirme que já existiam antes da sua
  mudança com `git stash` + rerun antes de assumir que são culpa sua.
- Rode `npx biome check --write <arquivos alterados>` para lint/format.

## Fase 4 — Testar

- Teste unitário (Vitest) para toda lógica pura nova
  (`npx vitest run <arquivo>.test.ts`).
- Teste e2e (Playwright, `apps/web/playwright/*.e2e.ts`) quando a mudança é
  um fluxo de UI ponta a ponta — siga o padrão dos testes vizinhos no mesmo
  arquivo (fixtures `users`, `bookFirstEvent`, etc). Rodar com:
  `NEXT_PUBLIC_IS_E2E=1 npx playwright test --config=playwright.config.ts --project=@calcom/web -g "<nome do teste>"`.
  Precisa do Postgres local rodando (`docker ps` deve mostrar
  `prisma-postgres-1` saudável na porta 5450 — se não, `colima start`) e do
  dev server (`yarn dev`, ou com `NEXT_PUBLIC_IS_E2E=1` se for rodar e2e).
- Rode também 1-2 testes vizinhos já existentes para checar regressão.
- Quando fizer sentido, valide visualmente com um script Playwright
  avulso (screenshot / leitura de clipboard) antes de reportar como pronto —
  não confie só no fato de compilar.
- Limpe artefatos de teste (`test-results/`, scripts avulsos em scratchpad)
  ao final.

## Fase 5 — Abrir o PR (automático, sem perguntar)

Depois que a implementação e os testes passarem:

1. Se estiver na branch `main`, crie uma branch nova
   (`feature/<slug-descritivo>` ou `fix/<slug-descritivo>`).
2. Faça commit com mensagem no padrão *conventional commits*
   (`feat(escopo): ...` / `fix(escopo): ...`), terminando com
   `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.
3. Dê push (`git push -u origin <branch>`).
4. Abra o PR com `gh pr create --base main` incluindo no corpo: resumo do
   que mudou, decisões de design relevantes (especialmente as que vieram da
   entrevista), e um "test plan" com o que foi rodado/validado. Termine o
   corpo com a linha `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
5. Se já existir um PR aberto cobrindo a mesma tarefa (retrabalho/correção),
   feche o antigo com `gh pr close <n> --comment "..."` explicando que foi
   substituído pelo novo, em vez de deixar os dois abertos.
6. Reporte o link do PR final ao usuário.

Não pergunte "posso abrir o PR?" — abra direto. Só pare antes disso se algo
da Fase 1-4 ficou de fato bloqueado (ex: resposta da entrevista não permite
decidir sozinho, ou um teste está falhando sem causa clara).
