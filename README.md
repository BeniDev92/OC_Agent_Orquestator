# OC Agent Orquestator

Configuración de [opencode](https://opencode.ai) que define un equipo de desarrollo multiagente: un orquestador que planifica, descompone y delega el trabajo en subagentes especializados (arquitecto, frontend, backend, QA, reviewer, devops y docs), más un agente profesor que solo explica código.

No contiene código de aplicación: es pura configuración de agentes.

## Estructura

```
opencode.json             Configuración global de opencode (mínima)
.opencode/rules/
  team.md                 Capa GLOBAL (reglas compartidas por todos los agentes)
.opencode/agents/         Capa ROLE (un archivo = un agente)
  orchestrator.md         Orquestador (primary)
  arquitecto.md           Subagente de arquitectura y contratos
  frontend.md             Subagente de UI
  backend.md              Subagente de APIs y lógica
  qa.md                   Subagente de tests
  reviewer.md             Subagente de code review (no edita)
  devops.md               Subagente de CI/CD, builds y deploys
  docs.md                 Subagente de documentación
  profesor.md             Agente profesor (primary, no edita)
```

La definición está organizada en dos capas para evitar duplicación:

- **GLOBAL** (`.opencode/rules/team.md`, inyectado a todos vía `instructions`): fronteras, política de decisión y niveles de autonomía, gestión de incertidumbre (FACT/ASSUMPTION/DECISION/QUESTION/RISK), jerarquía de prioridades, seguridad, política de git, protocolo de comunicación/handoff, formato de salida y Definition of Done base.
- **ROLE** (cada `.md` de `.opencode/agents/`): identidad, alcance (responsable / no responsable), inputs, autonomía, workflow, política de decisión, estándares de ingeniería del rol, testing y Definition of Done específica. Las secciones genéricas se heredan de la capa GLOBAL, no se duplican.

## Agentes

| Agente | Modo | Modelo | Edita | Ejecuta comandos | Rol |
|---|---|---|---|---|---|---|
| `orchestrator` | primary | deepseek-v4-flash | No | Solo `git` de lectura | Planifica, delega vía `task` e integra. |
| `profesor` | primary | deepseek-v4-flash | No | No | Explica código; no modifica archivos. |
| `arquitecto` | subagent | deepseek-v4-flash | No | Solo `git` de lectura | Define arquitectura y contratos antes de implementar. |
| `frontend` | subagent | deepseek-v4-flash | Sí | Sí | UI, componentes, estilos, a11y. |
| `backend` | subagent | deepseek-v4-flash | Sí | Sí | APIs, lógica de negocio, persistencia. |
| `qa` | subagent | deepseek-v4-flash | Sí | Sí | Tests y validación de requisitos. |
| `reviewer` | subagent | gpt-5.6-luna | No | Solo `git` de lectura | Code review y seguridad. |
| `devops` | subagent | deepseek-v4-flash | Sí | Sí | CI/CD, builds, despliegues e infraestructura. |
| `docs` | subagent | deepseek-v4-flash | Sí | No | README y documentación técnica. |

Los subagentes no pueden lanzar otros subagentes (`task: deny`) ni acceder a la web; el orquestador es el único que delega.

> **Nota**: `reviewer` usa el modelo `opencode-go/gpt-5.6-luna`. Si ese provider no está configurado, el subagente falla; opencode no tiene fallback de modelo por agente. Asegúrate de tenerlo disponible o cambia su `model`.

## Cómo usar

Abre opencode en la raíz de un proyecto:

- **Agente por defecto**: cualquiera de los primary (orquestador o profesor), ciclando con `Tab` o invocándolo con `@`.
- **Orquestador**: dale una tarea de desarrollo y él descompone, delega en los subagentes, verifica e integra.
- **Subagentes**: también se invocan directamente con `@arquitecto`, `@frontend`, `@backend`, `@qa`, `@reviewer`, `@devops`, `@docs`.
- **Profesor**: pídele que explique un trozo de código, un archivo o el proyecto completo.

## Cómo funciona el flujo

1. El orquestador analiza la petición y la descompone en subtareas, identificando dependencias.
2. Si la feature cruza frontend y backend, define primero el contrato de datos (delega en `arquitecto` para que lo proponga).
3. Delega con la herramienta `task` (en paralelo si no hay dependencias, en secuencia si las hay), siempre con objetivo, contexto, archivos y criterios de aceptación.
4. Integra los resultados y resuelve conflictos entre subagentes (re-delegando o preguntándote).
5. Antes de cerrar, exige que reviewer o qa validen el trabajo cuando aplique. Si reviewer pide cambios, re-delega el fix (máximo 2 iteraciones) y luego escala a ti si persiste.

## Reglas de especialización

Cada agente define en su `.md` (capa ROLE) identidad, alcance, inputs, autonomía, workflow, política de decisión, estándares de ingeniería, testing y Definition of Done específica. La capa GLOBAL (`team.md`) aporta lo común a todos:

- **Fronteras**: frontend no toca backend y viceversa; si necesitan algo del otro lado, reportan el contrato exacto (método, ruta, payload) al orquestador. QA no arregla lógica de producción; docs solo toca documentación; reviewer solo revisa.
- **Política de decisión**: niveles de autonomía (0 autónomo → 3 aprobación humana) y cuándo escalar al orquestador o al usuario.
- **Incertidumbre**: los agentes etiquetan hechos, supuestos, decisiones, preguntas y riesgos para que una suposición no se convierta en requisito.
- **Comunicación**: los handoffs entre agentes siguen un protocolo estructurado (contexto, completado, decisiones, archivos, interfaces, pendientes, riesgos, validación).
- **Verificación**: cada subagente declara su criterio de terminado (build/lint, tests, migraciones, a11y) y reporta qué archivos tocó y qué probó.
- **Seguridad**: reglas comunes (no secretos, inputs no confiables, no deshabilitar controles) + checklist de seguridad de reviewer.

## Validar la configuración de agentes

`check-models.ps1` valida los agentes (frontmatter, modo, permisos y modelos) y la disponibilidad de los modelos en opencode:

powershell -ExecutionPolicy Bypass -File check-models.ps1

- Si un provider no responde (p. ej. en CI sin credenciales globales), se omite esa verificación con un aviso; el fallo real (modelo ausente con provider consultable) corta con `exit 1`.
- El mismo script corre en CI (`.github/workflows/check-agents.yml`) en cada push y PR, en `windows-latest`.

## Usar este equipo en otros proyectos

`opencode.json` y `.opencode/` solo aplican si abres opencode en este repositorio. Para tener el equipo disponible en cualquier proyecto, copia la configuración a la carpeta global de opencode:

- **Windows**: `%USERPROFILE%\.config\opencode\`
- **Linux/macOS**: `~/.config/opencode/`

Copia `opencode.json` y la carpeta `.opencode/` ahí. Si ya tienes un `opencode.json` global, fusiona las claves (agents y reglas) en vez de sobrescribir.

La config global y la del proyecto se combinan: los agentes globales están siempre disponibles y los del proyecto los complementan.