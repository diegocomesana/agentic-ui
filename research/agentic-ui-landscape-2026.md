# Agentic UI — Landscape Research (Feb 2026)

## Executive Summary

Nuestra arquitectura — un LLM agent que **compone** (no genera) una UI desde un **catálogo de widgets predefinidos**, usando un **store centralizado** como fuente de verdad, con un **modelo declarativo** y una distinción clara entre **acciones mecánicas vs semánticas** — es un diseño bien diferenciado. El espacio explotó en 2025-2026 y hay varios proyectos y protocolos que se superponen con distintas partes de la visión. Ninguno implementa la arquitectura completa.

---

## 1. El Stack de Protocolos Emergente

La industria convergió en un stack de protocolos por capas para agentic UIs:

| Capa | Protocolo | Propósito | Relevancia |
|------|-----------|-----------|------------|
| Agent-to-Tools | **MCP** (Anthropic/OpenAI) | Invocación de tools, acceso a datos | Alta — nuestros tools usan MCP-standard format |
| Agent-to-Frontend | **AG-UI** (CopilotKit) | Streaming de eventos en tiempo real agent↔UI | Alta — comparable a nuestra comunicación agent-store |
| UI Specification | **A2UI** (Google) | Formato declarativo de descripción de UI | **Muy alta** — directamente comparable al widget descriptor |
| UI Specification | **Open-JSON-UI** (OpenAI) | Schema declarativo de UI | Alta — intención declarativa similar |

**Fuentes:**
- [AG-UI and A2UI Explained](https://www.copilotkit.ai/blog/ag-ui-and-a2ui-explained-how-the-emerging-agentic-stack-fits-together)
- [A2A, MCP, AG-UI, A2UI: The Essential 2026 AI Agent Protocol Stack](https://medium.com/@visrow/a2a-mcp-ag-ui-a2ui-the-essential-2026-ai-agent-protocol-stack-ee0e65a672ef)
- [The Agent Protocol Stack: Why MCP + A2A + A2UI Is the TCP/IP Moment](https://subhadipmitra.com/blog/2026/agent-protocol-stack/)

---

## 2. Matches Más Cercanos (Alto Overlap)

### 2.1 Google A2UI (Agent-to-User Interface)

- **GitHub:** https://github.com/google/A2UI
- **Spec:** https://a2ui.org/specification/v0.9-a2ui/
- **Licencia:** Apache 2.0
- **Estado:** v0.9, desarrollo activo

**Qué es:** Un formato de datos declarativo (no un framework) donde un agente envía una descripción JSON de un árbol de componentes y el cliente los mapea a widgets nativos de un catálogo pre-aprobado.

**Overlap con nuestra arquitectura:**
- Widget catalog donde el cliente define componentes trusted — **mapea directamente** al Widget Descriptor / Registry
- El agente solo puede solicitar componentes del catálogo — **matchea** el principio "el agente compone, no genera"
- Framework-agnostic: el mismo payload A2UI renderiza en web, Flutter, SwiftUI, etc.
- Security-first: datos declarativos, no código ejecutable

**Gaps vs nosotros:**
- A2UI es **solo una especificación de formato**. No define store, middleware, acciones mecánicas vs semánticas, ni capa de servicios
- Sin concepto de widgets "data-bound" vs "agent-filled"
- Sin concepto de acciones mecánicas que bypasean al agente
- Sin `dataSource` ni auto-resolution de data
- Sin reducers, spawn actions, ni guards

**Veredicto:** A2UI es el match más cercano a nuestra capa de **catálogo + composición declarativa**, pero cubre solo el formato. Le falta todo el runtime.

**Fuentes:**
- [Introducing A2UI - Google Developers Blog](https://developers.googleblog.com/introducing-a2ui-an-open-project-for-agent-driven-interfaces/)
- [A2UI Specification v0.9](https://a2ui.org/specification/v0.9-a2ui/)

---

### 2.2 CopilotKit + AG-UI Protocol

- **GitHub:** https://github.com/CopilotKit/CopilotKit
- **AG-UI Spec:** https://docs.ag-ui.com/
- **Licencia:** MIT (CopilotKit), open (AG-UI)
- **Estado:** Production-ready, adopción masiva

**Qué es:** Framework React/Angular para experiencias "AI copilot". AG-UI es el protocolo basado en eventos para comunicación agent-frontend. Implementa tres patrones de generative UI:

1. **Controlled Generative UI** — Componentes pre-construidos, el agente elige cuáles renderizar con qué data. **Más cercano a nuestro modelo.**
2. **Declarative Generative UI** — El agente retorna specs de UI estructuradas (A2UI, Open-JSON-UI).
3. **Open-ended Generative UI** — El agente genera HTML/markup completo.

**Overlap con nuestra arquitectura:**
- El patrón "Controlled" mapea a: widgets pre-construidos, agente decide cuáles mostrar con qué props
- AG-UI provee streaming de state patches, lifecycle events, tool calls
- Soporta múltiples backends LLM (LangGraph, CrewAI, etc.)

**Gaps vs nosotros:**
- Sin store centralizado como fuente de verdad con middleware de acciones mecánicas
- Sin distinción mecánico vs semántico — todas las interacciones fluyen por el agente
- Sin `dataSource` auto-resolution
- Sin agent scheduler que serialice invocaciones y descarte resultados stale
- React/Angular-specific (no LiveView/server-rendered)

**Veredicto:** El framework de producción más maduro para agent-driven UIs. Su patrón "controlled" se superpone con nuestra visión, pero le falta la arquitectura de store, data resolution, y el split mecánico/semántico.

**Fuentes:**
- [CopilotKit - Generative UI](https://www.copilotkit.ai/generative-ui)
- [AG-UI Protocol Overview](https://docs.ag-ui.com/)
- [The Developer's Guide to Generative UI in 2026](https://www.copilotkit.ai/blog/the-developer-s-guide-to-generative-ui-in-2026)

---

### 2.3 Tambo (Generative UI SDK for React)

- **GitHub:** https://github.com/tambo-ai/tambo
- **npm:** `@tambo-ai/react`
- **Licencia:** Open source
- **Estado:** v1.0, activo

**Qué es:** SDK React fullstack para generative UI. Se registran componentes con Zod schemas (que se convierten en tool definitions del LLM), y el agente elige qué componente renderizar y streamea props.

**Overlap con nuestra arquitectura:**
- **Registro de componentes con schemas** — similar al Widget Descriptor. Zod schemas definen el contrato
- Los schemas se convierten en tool definitions del LLM — similar a "tools derivadas del registry"
- El agente elige el componente y provee data — principio "el agente compone"
- Soporte MCP para data sources

**Gaps vs nosotros:**
- Sin store centralizado con diffing
- Sin split de acciones mecánicas vs semánticas
- Sin `dataSource` auto-resolution
- Sin reducers, spawn actions, guards, cart/wishlist state
- Sin agent scheduler ni multi-mode (agent-on/off)
- React-only

**Veredicto:** Arquitectónicamente cercano al patrón "catálogo + agente elige y llena", pero es significativamente más simple que nuestro diseño completo.

**Fuentes:**
- [Tambo Docs](https://docs.tambo.co/)
- [Tambo 1.0 - HN](https://news.ycombinator.com/item?id=46966182)

---

## 3. Proyectos Relacionados (Overlap Medio)

### 3.1 Flutter GenUI SDK (Google)

- **GitHub:** https://github.com/flutter/genui
- **Docs:** https://docs.flutter.dev/ai/genui

Librería Flutter que usa A2UI internamente. Cada `CatalogItem` combina un nombre, un schema y una builder function. El agente genera JSON referenciando catalog items y el SDK los renderiza. Es la **implementación runtime más completa** del concepto A2UI, pero solo Flutter.

**Fuentes:**
- [GenUI SDK for Flutter - Official Docs](https://docs.flutter.dev/ai/genui)
- [How to Use GenUI in Flutter](https://www.freecodecamp.org/news/how-to-use-genui-in-flutter-to-build-dynamic-ai-driven-interfaces/)

### 3.2 MCP Apps (Extensión oficial de MCP)

- **GitHub:** https://github.com/modelcontextprotocol/ext-apps
- **Blog:** [MCP Apps - Bringing UI Capabilities to MCP Clients](http://blog.modelcontextprotocol.io/posts/2026-01-26-mcp-apps/)

Tools pueden declarar UIs asociadas que se renderizan en iframes sandboxed. Adoptado por ChatGPT, Claude, VS Code. Filosofía distinta: iframe isolation en vez de composición de componentes nativos, y cada tool "es dueño" de su UI en vez de un agente orquestando un layout completo.

---

## 4. Research Académico

### 4.1 "Human-Centered LLM-Agent User Interface: A Position Paper" (2024)

- **Paper:** https://arxiv.org/abs/2405.13050

Introduce **LAUI (LLM-Agent User Interface)** — una capa compuesta, user-facing, que integra un backend cognitivo LLM, planificación proactiva y una GUI rica. Presenta "Flute X GPT" como implementación. Es el framing académico más cercano a nuestra arquitectura.

### 4.2 "From User Interface to Agent Interface" (2024)

- **Paper:** https://arxiv.org/html/2512.13438

Explora optimización de representaciones de UI para agentes LLM — directamente relevante al concepto de serialización de estado para el agente (nuestro `StateSummarizer` y el snapshot que se incluye en cada invocación).

---

## 5. Gap Analysis — Features Implementadas vs Landscape

### Nuestras features actuales

| Feature | Estado | Detalle |
|---------|--------|---------|
| **Widget catalog (12 tipos + 2 chat)** | Implementado | product_grid, product_carousel, product_detail, comparator, cart, wishlist, search_bar, category_browser, hero_banner, hero_carousel, top_products, main_menu + chat_product_card, chat_category_button |
| **Descriptor-driven architecture** | Implementado | Cada widget tiene descriptor con config schema, data source, events, reducers, spawn actions, agent instructions |
| **Store centralizado** | Implementado | Pure functional state: widgets, layout, conversation, cart, wishlist, pinning/locking |
| **Split mecánico vs semántico** | Implementado | Acciones mecánicas (pagination, filters, close) son instant. Semánticas van al agente |
| **Pluggable reducers** | Implementado | Cart (6 fns), Config (5 fns), Common (3 fns), Wishlist (4 fns) — declarados en descriptors |
| **Spawn actions** | Implementado | Auto-crear widgets en eventos (ej: click producto → product_detail) con template IDs |
| **DataSource auto-resolution** | Implementado | Engine resuelve data via service calls según config del descriptor |
| **Guard conditions** | Implementado | Bloquear eventos si params no pasan validación |
| **Semantic conditions** | Implementado | Redirigir evento al chat del agente según flag de config |
| **4 agent tools (MCP-standard)** | Implementado | search_products, get_product_detail, get_categories, get_products_by_ids |
| **Multi-turn tool calling** | Implementado | Hasta 20 rounds de tool invocation por request |
| **Provider-agnostic agent** | Implementado | Behaviour + OpenAI provider, extensible via AGENT_PROVIDER |
| **Agent scheduler** | Implementado | State machine: serializa invocaciones, descarta stale, auto-reinvoca |
| **Multi-mode (agent-on/off)** | Implementado | Dos modos con diferentes widgets por defecto, switch preserva cart/wishlist/conversation |
| **Pinning & locking** | Implementado | Widgets pinneados sobreviven clear. Locked = no removible |
| **Guest user persistence** | Implementado | UUID cookie + PostgreSQL (opcional) |
| **Theme support** | Implementado | Light/dark/system con daisyUI |
| **Debug panel** | Implementado | Estado en tiempo real, model name, widget/message count |
| **Chat widgets** | Implementado | Product cards y category buttons inline en mensajes del agente |
| **Undo/history** | Implementado | Session mantiene stack de snapshots |
| **State summarizer** | Implementado | Contexto del estado adjunto a cada mensaje para el agente |

### Qué no tiene nadie más

| Nuestro concepto | Match más cercano | Gap |
|---|---|---|
| **Store centralizado** (agente y widgets lo mutan via middleware unificado) | CopilotKit `useCoAgentStateRender` | Ningún proyecto usa un store funcional centralizado que tanto declaraciones del agente como acciones mecánicas muten |
| **Split mecánico vs semántico** | Ninguno | **Enteramente novel.** Todos los frameworks rutean todo por el agente. El bypass para paginación, sort, filters no está implementado en ningún lado |
| **Descriptor-driven widgets** (config + dataSource + events + reducers + spawn actions en un solo declarativo) | Tambo Zod schemas (parcial, solo config) | Ningún framework combina config schema, data resolution, event routing y spawn actions en una declaración unificada |
| **Spawn actions** (evento en widget A auto-crea widget B) | Ninguno | El patrón de "click producto en grid → auto-crear product_detail posicionado" no existe en otros frameworks |
| **Agent scheduler** (state machine que serializa, descarta stale, auto-reinvoca) | Ninguno | Los demás frameworks no manejan el problema de agente slow + UI fast (múltiples cambios durante ejecución del agente) |
| **Multi-mode agent-on/off** (misma app funciona con y sin agente) | Ninguno | Los demás frameworks asumen siempre-agente. Poder operar sin agente (búsqueda directa, navegación manual) no está contemplado |
| **Guard + semantic conditions** en eventos | Ninguno | Validar input antes de procesar + redirigir condicionalmente al agente según config flag del widget |
| **Chat widgets** (elementos interactivos inline en mensajes que spawnan workspace widgets) | Chainlit CustomElement (parcial) | Que un product card inline en un mensaje del chat spawne un widget completo en el workspace no existe en otros frameworks |

---

## 6. Tabla Comparativa

| Proyecto | Tipo | Widget Catalog | Store Centralizado | Split Mec/Sem | DataSource Auto-Resolve | Reducers/Spawn | Agent Scheduler | Multi-Mode |
|---|---|---|---|---|---|---|---|---|
| **Nosotros** | Framework completo (Elixir/LiveView) | 14 widgets | Si | Si | Si | Si | Si | Si |
| **A2UI** | Spec/formato | Si (spec) | No | No | No | No | No | No |
| **CopilotKit + AG-UI** | Framework (React/Angular) | Parcial | No | No | No | No | No | No |
| **Tambo** | SDK (React) | Si (Zod) | No | No | No | No | No | No |
| **Flutter GenUI** | SDK (Flutter) | Si (via A2UI) | No | No | No | No | No | No |
| **MCP Apps** | Extensión protocolo | No (iframe) | No | No | No | No | No | No |

---

*Investigación realizada en Febrero 2026. Actualizado con features implementadas.*
