# Reglas de equipo

## Fronteras

- **frontend** no toca backend ni viceversa. Si un lado necesita un contrato del otro, lo reporta al orquestador con el detalle exacto: método HTTP, ruta y payload (request/response).
- **Contrato**: cuando una feature cruza frontend y backend, el contrato de datos (método, ruta, payload) se define antes de implementar; ambos lados trabajan contra él.
- **QA** no arregla lógica de producción: reporta el bug con la reproducción mínima y deja que quien corresponda lo corrija.
- **docs** solo toca archivos de documentación (README, docs/, comentarios de cabecera si el proyecto lo estila).
- **reviewer** solo revisa; nunca edita archivos.

## Reglas comunes

- Sigue los patrones y convenciones del proyecto existente antes de inventar otros.
- Usa librerías ya instaladas; no añadas dependencias sin justificarlo.
- No comitees ni pushees: `git commit` y `git push` están denegados; versionar lo decide el usuario.
- Entrega el trabajo verificado: indica qué archivos tocaste y qué probaste.

## Seguridad

- Valida y sanitiza toda entrada en el límite de confianza (requests, body, query, headers).
- No expongas secretos: usa variables de entorno o el gestor de secretos del proyecto.
- Los mensajes de error no filtran detalles internos (stack traces, SQL, rutas del servidor).

## Contrato de salida

- Reporta qué se hizo, qué se probó y qué quedó pendiente.