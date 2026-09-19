# 001 — Ficar no webkit2gtk-4.1

**Data:** 2026-09-19
**Situação:** aceita

## O problema

O Skull Browser compila contra `webkit2gtk-4.1`, a API do WebKitGTK para GTK 3.
A versão atual da API upstream é `webkitgtk-6.0`, que exige GTK 4 e libsoup 3.

Duas frases da documentação oficial definem o risco.

Do guia de migração para a 6.0:

> All APIs that were previously deprecated in webkit2gtk-4.0 and webkit2gtk-4.1
> have been removed. [...] It also includes the entire GObject DOM API (e.g.
> `WebKitDOMDocument`), which has been **removed without replacement**. Use
> JavaScript to interact with and manipulate the DOM instead.

E, no mesmo documento:

> Beware that as of WebKitGTK 2.40, **the entire web process API may
> unfortunately be removed in the future.**

## Por que isso importa aqui

A segunda frase é a séria. A arquitetura do luakit — e portanto a nossa — é
construída em cima exatamente dessa API:

- `extension/` são ~1.900 linhas de C que existem para rodar uma VM Lua
  **dentro** do processo de renderização do WebKit
- os 10 módulos `lib/*_wm.lua` (~1.480 linhas) assumem acesso síncrono ao DOM
  a partir desse processo
- `extension/scroll.c` chega a definir `WEBKIT_DOM_USE_UNSTABLE_API` para obter
  a posição de rolagem

Se a API de processo web for removida, isso não é ajuste: cada propriedade
síncrona de `dom_element` vira uma ida e volta assíncrona, e os 10 módulos
precisam ser repensados.

Migrar para a 6.0 também arrasta GTK 3 → GTK 4, que é um porte independente e
maior que qualquer fase já planejada neste projeto.

## Decisão

**Ficar no `webkit2gtk-4.1`.** Não migrar agora.

A pressão real é baixa: a 4.1 é suportada upstream, o Ubuntu 24.04 entrega
WebKitGTK 2.52.6 com ela, e o build passa com avisos de depreciação apenas —
nenhum erro. Não há prazo anunciado para a remoção.

## Consequência operacional

**Não adicionar código novo em `extension/`.**

Código escrito ali é código com prazo de validade. Quando uma funcionalidade
puder ser feita no processo da interface, ou via `eval_js`, esse é o caminho —
mesmo que pareça mais desajeitado hoje.

## Quando revisar

- Quando uma distro que nos interessa parar de empacotar `webkit2gtk-4.1`
- Quando o upstream anunciar data para remover a API de processo web
- Se surgir necessidade que force crescer `extension/` — aí o custo da migração
  precisa ser comparado com o custo de continuar

## Fontes

- WebKit 6.0: Migrating WebKitGTK Applications to GTK 4 (documentação oficial)
- WebKitGTK API Versions Demystified — Michael Catanzaro, 2025-04-28
