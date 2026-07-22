# Family Brain Interface System

Цей документ — базове правило для всіх нових і змінених екранів Family Brain.

## Напрям

Інтерфейс наслідує принципи Apple-платформ: системна типографіка, чітка ієрархія,
спокійна щільність, мінімум декоративного тексту та матеріали з відчуттям глибини.
Liquid Glass використовується для оболонки й навігації, а не як ефект на кожному блоці.

## Джерело правди

Токени й компоненти живуть у `app/assets/tailwind/application.css`:

- кольори використовуються лише через `--ink`, `--muted`, `--accent`, `--panel`, `--line` та їх semantic variants;
- радіуси — через `--radius-*`;
- glass-поверхні — через `.liquid-glass`, `.data-card`, `.form-panel`, `.workspace-hero`;
- дії — через `.button`, `.cta-primary`, `.cta-secondary`;
- поля — через `.form-input`, `.form-select`, `.auth-input`;
- іконки — через `ui_icon` з `ApplicationHelper`.

## Правила композиції

1. Один головний заголовок і одна головна дія на viewport.
2. Glass застосовується до плаваючих shell-рівнів; внутрішні списки лишаються тихими й майже пласкими.
3. Не обгортати кожен абзац в окрему картку. Спочатку використовувати відступ, divider або list row.
4. Не використовувати serif-шрифти, uppercase з великим letter-spacing та декоративну нумерацію секцій.
5. Не показувати користувачу внутрішні терміни `RAG`, `semantic memory`, `procedural layer`, назви таблиць чи model pipeline.
6. Анімація має пояснювати зміну стану, тривати близько 180–240 ms і поважати `prefers-reduced-motion`.
7. Кожен екран перевіряється в системному dark mode та на ширині 390 px.

## Hotwire

Усі дії, що не потребують повної навігації, мають залишатися асинхронними:

- переходи між секціями workspace — через Turbo Frames;
- створення й оновлення сутностей — через `form_with` і Turbo Stream responses;
- фонові AI/automation стани — через Turbo Streams / broadcasts;
- локальна поведінка інтерфейсу — через невеликі Stimulus controllers без дублювання server state.

Під час переходу між Turbo-вкладками використовується `data-turbo-action="advance"`, щоб URL і browser history залишалися коректними.
