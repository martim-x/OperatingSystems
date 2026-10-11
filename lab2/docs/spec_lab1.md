# Спецификация оформления lab1.docx (эталон для ЛР2)

Источник: `lab1/lab1.docx` (Word 2019+, OOXML). Все значения вытащены напрямую
из `word/styles.xml`, `word/numbering.xml`, `word/document.xml`, `word/settings.xml`,
`word/header1.xml`, `word/footer1.xml`. Единицы: twips (1/20 pt), EMU (914400 EMU = 1 inch).

## 0. Главный приём сборки

**Не создавать стили заново.** Взять `lab1.docx` как шаблон и пересобрать только
`word/document.xml` (+ при необходимости `word/_rels/document.xml.rels` и
`word/media/`). Тогда `styles.xml`, `numbering.xml`, `theme1.xml`, `header1.xml`,
`footer1.xml`, `settings.xml` достаются готовыми и вид документа совпадает
документ в документ.

Именно так уже сделано в `lab2/make_docx_lab2.py`.

## 1. Страница и секция

Одна секция, `w:type="continuous"`:

```xml
<w:sectPr>
  <w:headerReference w:type="default" r:id="rId113"/>   <!-- номер страницы сверху -->
  <w:footerReference w:type="first"   r:id="rId114"/>   <!-- «Минск, 2026» только на 1-й стр. -->
  <w:type w:val="continuous"/>
  <w:pgSz w:w="11906" w:h="16838"/>                    <!-- A4 -->
  <w:pgMar w:top="1134" w:right="567" w:bottom="851" w:left="1304"
           w:header="709" w:footer="709" w:gutter="0"/>
  <w:cols w:space="708"/>
  <w:titlePg/>                                        <!-- разные колонтитулы 1-й стр. -->
  <w:docGrid w:linePitch="360"/>
</w:sectPr>
```

Поля страницы: верхнее 2 см, нижнее 1.5 см, левое 2.3 см, правое 1 см.
Полезная ширина строки = 11906 − 1304 − 567 = **10035 twips** (≈17.7 см) —
именно на неё завязаны табуляции в стилях `toc 1`/`toc 2` и на титуле.

`settings.xml`: `defaultTabStop=708`, `compatibilityMode=15`,
`updateFields` **отсутствует** (оглавление обновляется вручную в Word).

## 2. docDefaults (styles.xml)

```xml
<w:docDefaults>
  <w:rPrDefault><w:rPr>
    <w:rFonts w:asciiTheme="minorHAnsi" w:eastAsiaTheme="minorHAnsi"
              w:hAnsiTheme="minorHAnsi" w:cstheme="minorBidi"/>
    <w:sz w:val="22"/><w:szCs w:val="22"/>
    <w:lang w:val="ru-RU" w:eastAsia="en-US" w:bidi="ar-SA"/>
  </w:rPr></w:rPrDefault>
  <w:pPrDefault><w:pPr>
    <w:spacing w:after="160" w:line="259" w:lineRule="auto"/>
  </w:pPr></w:pPrDefault>
</w:docDefaults>
```

Тема: minor = Calibri, major = Calibri Light. **Calibri в документе не видно** —
все видимые стили переопределяют шрифт на Times New Roman.

## 3. Используемые стили (полные определения)

| styleId | имя | роль |
|---|---|---|
| `a2` | Normal | база для всего; Times New Roman 12 pt, интервал 240 auto, after 0 |
| `a0` | Глава_диплома | заголовок главы, нумеруется, 14 pt bold |
| `a1` | Раздел_диплома | заголовок раздела (1.1), 14 pt bold |
| `a` | Подраздел_диплома | уровень 3 (1.1.1) — в lab1 **не используется** |
| `aff2` | Для текста | основной текст: 14 pt, отступ 709, по ширине |
| `ad` | Текст диплома | титульный лист, 14 pt, отступ 709, по ширине |
| `af0` | Normal (Web) | **подпись рисунка** «Рисунок N.M – …», по центру |
| `12` | toc 1 | строка оглавления 1-го уровня |
| `22` | toc 2 | строка оглавления 2-го уровня |
| `af8` | TOC Heading | заголовок «Оглавление» (переопределён) |
| `a8` | Hyperlink | символьный, `0563C1` + underline |
| `ae`/`af` | header | верхний колонтитул |
| `a6`/`a7` | footer | нижний колонтитул |

НЕ использовать: `aff6` («[К] Рисунок»), `af3` (caption), `10`/`20` (heading 1/2),
`af9` (Body Text), `a9` (List Paragraph), `code-line`, `p1…p6`, `s1…s5`.

### 3.1 `a2` — Normal (корень всего)

```xml
<w:style w:type="paragraph" w:default="1" w:styleId="a2">
  <w:name w:val="Normal"/>
  <w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr>
  <w:rPr><w:rFonts w:ascii="Times New Roman" w:eastAsia="Times New Roman"
                   w:hAnsi="Times New Roman" w:cs="Times New Roman"/>
         <w:sz w:val="24"/><w:szCs w:val="24"/>
         <w:lang w:eastAsia="ru-RU"/></w:rPr>
</w:style>
```

### 3.2 `aff2` — «Для текста» (основной текст, 188 абзацев в lab1)

```xml
<w:style w:type="paragraph" w:customStyle="1" w:styleId="aff2">
  <w:name w:val="Для текста"/><w:basedOn w:val="a2"/><w:link w:val="aff3"/><w:qFormat/>
  <w:pPr><w:shd w:val="clear" w:color="auto" w:fill="FFFFFF"/>
         <w:ind w:firstLine="709"/><w:jc w:val="both"/></w:pPr>
  <w:rPr><w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr>
</w:style>
```

Итог: **Times New Roman 14 pt, одинарный интервал, отступ первой строки 709 twips
(1.25 см), выравнивание по ширине, белый фон.** Шрифт наследуется от `a2`.

### 3.3 `a0` — Глава_диплома (заголовок главы)

```xml
<w:style w:type="paragraph" w:customStyle="1" w:styleId="a0">
  <w:name w:val="Глава_диплома"/><w:basedOn w:val="a2"/><w:qFormat/>
  <w:pPr><w:numPr><w:numId w:val="6"/></w:numPr>
         <w:tabs><w:tab w:val="num" w:pos="360"/></w:tabs>
         <w:spacing w:before="360" w:after="240"/>
         <w:outlineLvl w:val="0"/></w:pPr>
  <w:rPr><w:rFonts w:eastAsiaTheme="minorEastAsia"/><w:b/>
         <w:sz w:val="28"/><w:szCs w:val="32"/></w:rPr>
</w:style>
```

**Times New Roman 14 pt bold**, перед 18 pt / после 12 pt, `outlineLvl=0`
(попадает в оглавление, уровень 1).

### 3.4 `a1` — Раздел_диплома (заголовок раздела)

```xml
<w:style w:type="paragraph" w:customStyle="1" w:styleId="a1">
  <w:name w:val="Раздел_диплома"/><w:link w:val="ab"/><w:qFormat/>
  <w:pPr><w:numPr><w:ilvl w:val="1"/><w:numId w:val="6"/></w:numPr>
         <w:tabs><w:tab w:val="num" w:pos="360"/></w:tabs>
         <w:spacing w:before="360" w:after="360" w:line="240" w:lineRule="auto"/>
         <w:ind w:left="0" w:firstLine="0"/>
         <w:outlineLvl w:val="1"/></w:pPr>
  <w:rPr><w:rFonts w:ascii="Times New Roman" w:eastAsiaTheme="minorEastAsia"
                   w:hAnsi="Times New Roman" w:cs="Times New Roman"/><w:b/>
         <w:sz w:val="28"/><w:szCs w:val="32"/>
         <w:lang w:eastAsia="ru-RU"/></w:rPr>
</w:style>
```

**Times New Roman 14 pt bold**, перед/после 18 pt, `outlineLvl=1` (уровень 2 в оглавлении).

### 3.5 `af0` — Normal (Web) (подпись рисунка)

```xml
<w:style w:type="paragraph" w:styleId="af0">
  <w:name w:val="Normal (Web)"/><w:basedOn w:val="a2"/>
  <w:pPr><w:spacing w:before="100" w:beforeAutospacing="1"
                   w:after="100" w:afterAutospacing="1"/></w:pPr>
</w:style>
```

Стиль сам по себе пустой. Всё оформление подписи задаётся **на абзаце**:
`<w:jc w:val="center"/>` + `<w:sz w:val="28"/>` (14 pt) в pPr/rPr и в каждом run.
Пример фактического абзаца подписи:

```xml
<w:p><w:pPr><w:pStyle w:val="af0"/><w:jc w:val="center"/>
  <w:rPr><w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr></w:pPr>
  <w:r><w:rPr><w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr>
  <w:t>Рисунок 1.1 – Главное окно VMware Fusion и запуск добавления виртуальной машины</w:t></w:r>
</w:p>
```

Формат текста: **`Рисунок N.M – <описание>`** — номер главы, точка, номер рисунка
в главе, пробел, **en-dash (–)**, пробел, описание. Шрифт TNR 14 pt, по центру,
без курсива, цвет чёрный (не `44546A`, как у стиля `caption`).

### 3.6 `ad` — Текст диплома (титульный лист)

```xml
<w:style w:type="paragraph" w:customStyle="1" w:styleId="ad">
  <w:name w:val="Текст диплома"/><w:basedOn w:val="a2"/><w:qFormat/>
  <w:pPr><w:ind w:firstLine="709"/><w:jc w:val="both"/></w:pPr>
  <w:rPr><w:rFonts w:eastAsiaTheme="minorEastAsia"/>
         <w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr>
</w:style>
```

### 3.7 `12` / `22` — строки оглавления

```xml
<!-- toc 1 -->
<w:pPr><w:tabs><w:tab w:val="left" w:pos="284"/>
                 <w:tab w:val="right" w:leader="dot" w:pos="10035"/></w:tabs>
       <w:jc w:val="both"/></w:pPr>
<w:rPr><w:noProof/><w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr>

<!-- toc 2 -->
<w:pPr><w:tabs><w:tab w:val="right" w:leader="dot" w:pos="10035"/></w:tabs>
       <w:ind w:firstLine="227"/></w:pPr>
```

Обе строки: TNR 14 pt, правый таб с точечным заполнителем на 10035 (ровно
по правому краю текстового блока), номер страницы вставлен полем `PAGEREF`.
Уровень 1 — по ширине, уровень 2 — с отступом 227.

### 3.8 `af8` — TOC Heading (заголовок «Оглавление»)

Стиль основан на heading 1 (синий 16 pt), но в документе переопределён на абзаце:

```xml
<w:p><w:pPr><w:pStyle w:val="af8"/>
  <w:spacing w:before="0" w:after="360"/><w:jc w:val="center"/>
  <w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"
                   w:cs="Times New Roman"/><w:b/><w:color w:val="auto"/>
         <w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr></w:pPr>
  <w:r><w:rPr>…то же…</w:rPr><w:t>Оглавление</w:t></w:r></w:p>
```

Результат: TNR 14 pt **bold**, по центру, цвет автоматический (чёрный),
`outlineLvl=9` (в оглавление не попадает).

## 4. Нумерация заголовков (numbering.xml) — критично

Все заголовки нумеруются **одним** abstract-списком `abstractNumId=14`
(`numId=6`), привязанным к стилям `a0` (ilvl 0) и `a1` (ilvl 1):

```xml
<w:abstractNum w:abstractNumId="14">
  <w:multiLevelType w:val="multilevel"/>
  <w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/>
    <w:pStyle w:val="a0"/><w:suff w:val="space"/><w:lvlText w:val="%1"/>
    <w:lvlJc w:val="left"/><w:pPr><w:ind w:left="0" w:firstLine="0"/></w:pPr>
    <w:rPr><w:sz w:val="28"/><w:szCs w:val="32"/></w:rPr></w:lvl>
  <w:lvl w:ilvl="1"><w:start w:val="4"/><w:numFmt w:val="decimal"/>
    <w:pStyle w:val="a1"/><w:isLgl/><w:suff w:val="space"/>
    <w:lvlText w:val="%1.%2"/><w:lvlJc w:val="left"/>
    <w:pPr><w:ind w:left="375" w:hanging="375"/></w:pPr>
    <w:rPr><w:sz w:val="28"/><w:szCs w:val="32"/></w:rPr></w:lvl>
</w:abstractNum>
```

Ключевое: `w:suff w:val="space"` — после номера **пробел, а не табуляция**;
номер и текст заголовка идут в одной строке («1 Создание и настройка…»).
Номер рендерится TNR 14 pt bold (тот же `rPr`, что у стиля).

**Сброс счётчика раздела.** В lab1 у каждой главы свой `w:num` поверх того же
abstract 14, с `lvlOverride/startOverride`, чтобы нумерация разделов
начиналась с 1 при сохранении номера главы:

| глава | numId | ilvl0 start | ilvl1 start | первый заголовок главы несёт |
|---|---|---|---|---|
| 1 Создание и настройка ВМ | 22 | 1 | 1 | `<w:numPr><w:ilvl w:val="1"/><w:numId w:val="22"/></w:numPr>` |
| 2 Установка windows 11 | 23 | 2 | 1 | `numId=23` |
| 3 Установка arch linux arm | 24 | 3 | 1 | `numId=24` |
| 4 Аппаратная конфигурация | 26 | 4 | 2 | `numId=26` (раздел 4.1 идёт первым) |
| — подраздел «Часть windows» | 27 | 4 | 1 | `numId=27` |

То есть **номер главы задаётся только на первом разделе главы**, дальше
`numPr` наследуется из стиля. Для ЛР2 нужно то же самое: глава N получает
свой `w:num` с `startOverride= N` и `startOverride=1` на ilvl1, и этот numId
проставляется только на первом `a1` внутри главы.

### 4.1 Введение и Заключение — без номера

Заголовки «Введение» и «ЗАКЛЮЧЕНИЕ» используют `a0`, но снимают нумерацию:

```xml
<w:pPr><w:pStyle w:val="a0"/>
  <w:numPr><w:ilvl w:val="0"/><w:numId w:val="0"/></w:numPr>  <!-- numId=0 = нет списка -->
  <w:jc w:val="center"/></w:pPr>
```

и выравнены **по центру**, тогда как нумерованные главы — по левому краю
с отступом первой строки 709 (имитация абзацного отступа):

```xml
<w:pPr><w:pStyle w:val="a0"/>
  <w:tabs><w:tab w:val="clear" w:pos="360"/></w:tabs>
  <w:ind w:firstLine="709"/></w:pPr>
```

## 5. Структура документа (порядок и разрывы)

Всего 487 абзацев. Распределение стилей:
`aff2` 188, `af0` 104, без стиля 77, `ad` 38, `22` 33, `a1` 33, `12` 6, `a0` 6, `af8` 2.

Порядок:

1. **Титульный лист** — абзацы 0…38, стиль `ad` (или без стиля для первых четырёх).
2. **Абзац с разрывом страницы** (пустой, стиль `af8`, внутри `<w:br w:type="page"/>`).
3. **«Оглавление»** — один абзац `af8` (см. 3.8), затем `<w:sdt>` с полем TOC.
4. **Основная часть** — чередуются: `a0` (глава) / `a1` (раздел) / `aff2` (текст) /
   абзац с картинкой + `af0` (подпись).
5. **ЗАКЛЮЧЕНИЕ** — `a0` по центру без номера, затем `aff2`.
6. Пустой абзац в конце.

### 5.1 Разрыв страницы перед каждой главой

Перед каждым заголовком `a0` (все 6 штук, включая Введение и Заключение) стоит
**отдельный пустой абзац с разрывом страницы**:

```xml
<w:p><w:pPr><w:spacing w:after="160" w:line="259" w:lineRule="auto"/></w:pPr>
  <w:r><w:br w:type="page"/></w:r></w:p>
```

Перед `a1` разрывов нет.

### 5.2 Закладки

Каждый заголовок `a0`/`a1` обёрнут в bookmark `_TocNNNNNNNNN` (нужен для
`PAGEREF` в оглавлении):

```xml
<w:bookmarkStart w:id="0" w:name="_Toc240915942"/>
<w:r><w:lastRenderedPageBreak/><w:t>Введение</w:t></w:r>
<w:bookmarkEnd w:id="0"/>
```

`w:lastRenderedPageBreak` — артефакт Word, генерировать не нужно.
Нумерация `_Toc` в lab1: 240915942 … 240915980.

## 6. Титульный лист (дословно)

Абзацы 0…38, стиль `ad` = TNR 14 pt. Пустые `ad`-абзацы — вертикальные
отступы (их количество подбирается по месту, в lab1 между блоками стоят
пустые абзацы; переносы строк внутри абзаца делаются `<w:br/>`).

| № | Содержимое | pPr |
|---|---|---|
| 0 | `МИНИСТЕРСТВО ОБРАЗОВАНИЯ РЕСПУБЛИКИ БЕЛАРУСЬ` + `<w:br/>` + `Учреждение образования «БЕЛОРУССКИЙ ГОСУДАРСТВЕННЫЙ ` + `<w:br/>` + `ТЕХНОЛОГИЧЕСКИЙ УНИВЕРСИТЕТ»` | без стиля; `spacing after=240 line=254 auto`; `jc=center`; sz 28 |
| 1 | `Факультет` [tab] `Информационных` ` ` `технологий` | без стиля; `tabs: left@2160, left@10035`; `snapToGrid=0`; `spacing line=254 auto`; **подчёркивание** |
| 2 | `Кафедра` [tab] `Информационных систем и технологий` | то же + подчёркивание |
| 3 | `Специальность` [tab] `6-05-0611-01 «Информационные системы и технологии»` | то же + подчёркивание |
| 4 | `Дисциплина ` [tab] `Программирование сетевых приложений` | `ad`, `ind firstLine=0`; **подчёркивание** |
| 5…15 | пустые `ad` | — |
| 16 | `Лабораторная работа № 1` | `ad`, `ind firstLine=0`, `jc=center` |
| 17 | `ЗНАКОМСТВО С ОС: УСТАНОВКА И АППАРАТНАЯ КОНФИГУРАЦИЯ` | `ad`, `ind firstLine=0`, `jc=center` |
| 18…31 | пустые `ad` | — |
| 32 | `студент 3 курса 2 группы` | `ad`; `tabs left@7088`; `ind firstLine=6804`; `jc=left` |
| 33 | `Марушко Т. Ф` | то же |
| 34 | `ассистент` | то же |
| 35 | `Савельева М.Г.` | то же + `color=000000` |
| 36…38 | пустые `ad` | — |

Ключевой приём титула: подпись исполнителя выровнена по **правому краю**
не через `jc=right`, а через огромный `w:firstLine="6804"` (≈12 см) — базовая
линия текста начинается с 12 см и идёт до правого поля.

Название работы в верхнем регистре, шрифт обычный (не bold).

## 7. Оглавление

Обёрнуто в content control:

```xml
<w:sdt>
  <w:sdtPr><w:id w:val="-5909584"/>
    <w:docPartObj><w:docPartGallery w:val="Table of Contents"/>
      <w:docPartUnique/></w:docPartObj></w:sdtPr>
  <w:sdtContent>
    <w:p><w:pPr><w:pStyle w:val="12"/></w:pPr>
      <w:r><w:fldChar w:fldCharType="begin"/></w:r>
      <w:r><w:instrText xml:space="preserve"> TOC \o "1-3" \h \z \u </w:instrText></w:r>
      <w:r><w:fldChar w:fldCharType="separate"/></w:r>
      … пункты оглавления (см. ниже) …
      <w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>
    … остальные абзацы пунктов, каждый со стилем 12 или 22 …
  </w:sdtContent>
</w:sdt>
```

Поле: ` TOC \o "1-3" \h \z \u ` — «собирать» заголовки 1-3 уровня, как
гиперссылки, скрывать табуляции в вебе, использовать outline level.

Каждая строка оглавления — hyperlink на закладку заголовка, внутри:
`run` с текстом (rStyle `a8`), `run` с `webHidden` + `<w:tab/>`,
затем `PAGEREF _TocNNNNNNNNN \h` в `webHidden`-прогонах, и последний
`webHidden`-run с номером страницы.

В lab1 в оглавлении 6 строк уровня 1 (стиль `12`) и 33 строки уровня 2 (стиль `22`).
Заголовок «Введение» присутствует (стиль `12`).

## 8. Колонтитулы

### header1.xml (верхний, на всех страницах кроме первой)

Абзац стиля `ae` (header), **выравнивание вправо**, TNR 14 pt,
`<w:ind w:firstLine="425"/>`, внутри `<w:sdt>` с
`docPartGallery="Page Numbers (Top of Page)"` — поле `PAGE \* MERGEFORMAT`:

```xml
<w:p><w:pPr><w:pStyle w:val="ae"/><w:ind w:firstLine="425"/>
  <w:jc w:val="right"/>
  <w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"
                   w:cs="Times New Roman"/><w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr></w:pPr>
  <w:r><w:rPr>…</w:rPr><w:fldChar w:fldCharType="begin"/></w:r>
  <w:r><w:rPr>…</w:rPr><w:instrText>PAGE   \* MERGEFORMAT</w:instrText></w:r>
  <w:r><w:rPr>…</w:rPr><w:fldChar w:fldCharType="separate"/></w:r>
  <w:r><w:rPr>…</w:rPr><w:t>2</w:t></w:r>
  <w:r><w:rPr>…</w:rPr><w:fldChar w:fldCharType="end"/></w:r>
</w:p>
```

Номер страницы печатается **справа вверху**, TNR 14 pt.

### footer1.xml (нижний, только первая страница — из-за `<w:titlePg/>`)

Один абзац, стиль `ad`, TNR 14 pt, по центру:
`Минск, 2026` (два run: `Минск` с `lang=ru-GB` и `, 2026`).

```xml
<w:p><w:pPr><w:pStyle w:val="ad"/><w:tabs><w:tab w:val="left" w:pos="6521"/></w:tabs>
  <w:ind w:firstLine="0"/><w:jc w:val="center"/></w:pPr>
  <w:r><w:t>Минск</w:t></w:r><w:r><w:t>, 2026</w:t></w:r></w:p>
```

## 9. Рисунки

- Ноль таблиц (`<w:tbl>` в документе нет).
- 105 картинок `word/media/imageN.png`, все `wp:inline` (не плавающие),
  `distT/B/L/R = 0`.
- Абзац с картинкой: либо без стиля + `<w:jc w:val="center"/>`, либо стиль
  `aff2` + `<w:jc w:val="center"/>` (доминирующий вариант), run с
  `<w:noProof/>`, `<w:drawing>`.
- Размер задаётся `<wp:extent cx=… cy=…>` в EMU; в `pic:spPr/a:xfrm/a:ext`
  дублируется. В lab1 ширина картинок 2.7M…5.7M EMU (7.5…16 см).
  Верхняя граница в эталоне — около 16 см (сравнимо с шириной текста 17.7 см).
- Сразу за абзацем с картинкой идёт абзац `af0` с подписью (см. 3.5).
- `docPr id` уникальны (57, 58, 59, …), `wp14:anchorId`/`editId` — hex-8.

Рекомендация для скрипта: масштабировать картинку так, чтобы
`cx <= 16 см` (5760000 EMU), сохраняя пропорции cy/cx.

## 10. Мелочи, которые легко упустить

- Разделитель в подписи рисунка — **en-dash `–` (U+2013)**, не дефис и не em-dash.
- Тире в тексте («Цель лабораторной работы – освоение…») тоже en-dash.
- Основной текст — 14 pt (**28 half-points**), не 12 pt. `Normal` = 24, но
  `aff2`/`ad`/`a0`/`a1` переопределяют на 28.
- Межстрочный интервал везде одинарный (`line=240 auto`), `after` у `a2` = 0.
- Шрифт **везде Times New Roman**; Calibri из темы не применяется нигде.
- Нет курсива, нет подчёркивания в основном тексте (кроме титула).
- Красный цвет `EE0000` в lab1 встречается только в перечислении задач во
  Введении — артефакт, воспроизводить не нужно.
- `noProof` на картинках и `webHidden` в оглавлении — служебное.
- `<w:proofErr w:type="spellStart/spellEnd">` (нумерация автопроверки) —
  артефакт Word, генерировать не нужно.

## 11. Чек-лист для скрипта сборки ЛР2

1. Скопировать `lab1.docx` как шаблон; заменить `word/document.xml`,
   `word/_rels/document.xml.rels`, `word/media/*`, `docProps/core.xml`.
2. Удалить из `document.xml` старые `<w:drawing>`, `bookmarkStart/End`,
   старый `<w:sdt>` оглавления, все `w:p`.
3. Титул: 4 абзаца без стиля (подчёркивание, табуляции 2160/10035),
   `ad` c `ind firstLine=0` для «Дисциплина», пустые `ad` разделители,
   «Лабораторная работа № 2» + тема, пустые `ad`, блок подписей с
   `firstLine=6804`, `jc=left`.
4. Разрыв страницы + «Оглавление» (`af8`, override) + `<w:sdt>` с `TOC \o "1-3" \h \z \u`.
5. Основная часть: для каждой главы — пустой абзац с `<w:br w:type="page"/>`,
   затем `a0` c `<w:ind w:firstLine="709"/>` и bookmark; для каждого раздела —
   `a1` c `<w:ind w:firstLine="709"/>`, на первом разделе главы —
   `<w:numPr><w:ilvl w:val="1"/><w:numId w:val="N"/></w:numPr>`.
6. Текст — `aff2`. Перечисления — `aff2` + `<w:ind w:left="709" w:firstLine="0"/>`.
7. Картинка — `aff2` + `jc=center`, ниже подпись `af0` + `jc=center` + sz 28,
   текст `Рисунок N.M – …`.
8. «Введение» и «ЗАКЛЮЧЕНИЕ» — `a0` + `numId=0` + `jc=center`, каждое с
   разрывом страницы.
9. `settings.xml` не трогать (нет `updateFields` — TOC обновить вручную).
10. Проверить: 14 pt везде, TNR, отступ 709, en-dash в подписях, номера
    страниц в правом верхнем углу, «Минск, 2026» внизу первой страницы.
