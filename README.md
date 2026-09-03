# OC Agent Orquestator

Configuración de [opencode](https://opencode.ai) que define un equipo de desarrollo multiagente: un orquestador que planifica, descompone y delega el trabajo en subagentes especializados (frontend, backend, QA, reviewer y docs), más un agente profesor que solo explica código.

No contiene código de aplicación: es pura configuración de agentes.

## Estructura

```
opencode.json             Configuración global de opencode (mínima)
.opencode/agents/         Definición de los agentes (un archivo = un agente)
  orchestrator.md         Orquestador (primary)
  frontend.md             Subagente de UI
  backend.md              Subagente de APIs y lógica
  qa.md                   Subagente de tests
  reviewer.md             Subagente de code review (no edita)
  docs.md                 Subagente de documentación
  profesor.md             Agente profesor (primary, no edita)
```

## Agentes

| Agente | Modo | Modelo | Edita | Ejecuta comandos | Rol |
|---|---|---|---|---|---|
| `orchestrator` | primary | deepseek-v4-flash | No | Solo `git` de lectura | Planifica, delega vía `task` e integra. |
| `profesor` | primary | deepseek-v4-flash | No | No | Explica código; no modifica archivos. |
| `frontend` | subagent | deepseek-v4-flash | Sí | Sí | UI, componentes, estilos, a11y. |
| `backend` | subagent | deepseek-v4-flash | Sí | Sí | APIs, lógica de negocio, persistencia. |
| `qa` | subagent | deepseek-v4-flash | Sí | Sí | Tests y validación de requisitos. |
| `reviewer` | subagent | gpt-5.6-luna | No | No | Code review y seguridad. |
| `docs` | subagent | deepseek-v4-flash | Sí | No | README y documentación técnica. |

Los subagentes no pueden lanzar otros subagentes (`task: deny`) ni acceder a la web; el orquestador es el único que delega.

> **Nota**: `reviewer` usa el modelo `opencode-go/gpt-5.6-luna`. Si ese provider no está configurado, el subagente falla; opencode no tiene fallback de modelo por agente. Asegúrate de tenerlo disponible o cambia su `model`.

## Cómo usar

Abre opencode en la raíz de un proyecto:

- **Agente por defecto**: cualquiera de los primary (orquestador o profesor), ciclando con `Tab` o invocándolo con `@`.
- **Orquestador**: dale una tarea de desarrollo y él descompone, delega en los subagentes, verifica e integra.
- **Subagentes**: también se invocan directamente con `@frontend`, `@backend`, `@qa`, `@reviewer`, `@docs`.
- **Profesor**: pídele que explique un trozo de código, un archivo o el proyecto completo.

## Cómo funciona el flujo

1. El orquestador analiza la petición y la descompone en subtareas, identificando dependencias.
2. Delega con la herramienta `task` (en paralelo si no hay dependencias, en secuencia si las hay), siempre con objetivo, contexto, archivos y criterios de aceptación.
3. Integra los resultados y resuelve conflictos entre subagentes (re-delegando o preguntándote).
4. Antes de cerrar, exige que reviewer o qa validen el trabajo cuando aplique.

## Reglas de especialización

- **Fronteras**: frontend no toca backend y viceversa; si necesitan algo del otro lado, reportan el contrato exacto (método, ruta, payload) al orquestador. QA no arregla lógica de producción; docs solo toca documentación.
- **Verificación**: cada subagente declara su criterio de terminado (build/lint, tests, migraciones, a11y) y reporta qué archivos tocó y qué probó.
- **Seguridad**: backend valida entradas y no comitea secretos; reviewer aplica un checklist (secretos, inyección, autorización, sanitización) y termina con veredicto `aprobar` o `cambios requeridos`.

## Ejecutar el verificador de agentes

powershell -ExecutionPolicy Bypass -File check-models.ps1