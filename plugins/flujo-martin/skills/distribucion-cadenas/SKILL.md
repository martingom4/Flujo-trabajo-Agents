---
name: distribucion-cadenas
description: 'Reporte de distribución y cumplimiento por sucursal de una casa contra su lista de productos infaltables: fuentes (sell-in LX + plataformas de cadena), identidad de producto, mapeo cliente→sucursal, especificación del Excel (matriz, listado de cumplimiento, hojas de stock) y las trampas de datos. Usar para replicar el análisis McCormick con otra casa o cadena.'
---

# Distribución y cumplimiento por sucursal vs. lista de infaltables

Cómo se arma el reporte que responde **"¿en qué sucursales de cada cadena está cada producto
que el cliente exige, dónde falta y cuánto cumple cada tienda?"**. Construido para McCormick
(casa `MQ`) en agosto 2026; la mecánica sirve para cualquier casa que Feduro distribuya a
cadenas.

## Cuándo activar

- Un proveedor manda su lista de "productos infaltables" / "portafolio de medición" y pide medir distribución
- Hay que cruzar sell-in de Feduro contra el sell-out o el inventario que reporta una cadena
- Hay que armar o corregir el listado de cumplimiento por sucursal / por categoría
- Aparece la pregunta "¿por qué este SKU no matchea con nuestra base?"
- Se quiere replicar `INFALTABLES_POR_SUCURSAL.xlsx` para otra casa

---

## 1. Qué se mide: presencia, no venta

**Presencia** = el producto está listado / despachado / con stock en esa sucursal.
Medir por venta subestima: XTRA daba 60.8% por venta y 73.6% por presencia.

| Fuente disponible | Criterio de presencia |
| --- | --- |
| Solo sell-in LX | se le facturó ese producto a esa sucursal en el período |
| Plataforma de la cadena | stock > 0 **o** tránsito > 0 **o** venta > 0 en la ventana |

La grilla de las plataformas es **dispersa**: *no hay fila* significa "no listado", fila con
venta 0 significa "listado sin venta". Son tres estados, no dos. Si se colapsan, la
distribución se subestima.

**Decisión de presentación (usuario, 2026-08-17):** la celda tiene 2 estados —
`X` verde = hay producto · vacío = no hay. Se descartó el estado "P/recuperable"
(tuvo venta antes y la perdió); el objetivo es binario. El dato histórico se puede
recuperar de `HISTORICO_VENTAS_CADENAS` si vuelve a pedirse.

---

## 2. Identidad de producto — la parte que más rompe

### El código Feduro son los últimos 6 dígitos del código de barra

Verificado 127 de 128 casos. `52100013848` → `MQ-013848`. Única excepción observada:
`7411000208199` → `MQ-208199B` (sufijo `B` de bandeo).

```python
cod_feduro = 'MQ-' + barcode_normalizado[-6:]      # normalizado = sin ceros a la izquierda
```

### Los EAN de la lista del cliente vienen truncados

La lista de McCormick trae el EAN **sin dígito verificador y/o sin ceros a la izquierda**, de
forma inconsistente: `5210000626` es `052100006260`, `741100021982` es `7411000219825`.
Matchear literal contra `SELLOUT.COD_PRODUCTO` reportó **45 productos "que no existen en
Panamá"** — eran 9. Secuencia de match, de más fuerte a más débil:

1. **Exacto** contra `SELLOUT.COD_PRODUCTO.COD_BARRA` (normalizando ceros de los dos lados)
2. **Truncado**: el EAN de la lista es prefijo del barcode real (falta el verificador)
3. **Por código de LX**: aplicar la regla de los 6 dígitos y buscar el `MQ-xxxxxx` en
   `PTYLX833F.IIM`. Rescata productos que existen en el ERP aunque no tengan barcode
   cargado en `SELLOUT.COD_PRODUCTO` — sin barcode no hay presencia por plataforma,
   pero **sí por sell-in**
4. Validar cada match por descripción **y gramaje** (`5210003835 PIMIENTO ROJO 130GR` →
   `MQ-038353 PEPPER RED CRUSH 6/4.62OZ` = 131 g ✓)

**No usar fuzzy match de descripciones.** difflib sobre estas descripciones matchea el
empaque, no el producto (da "HOJAS DE ALBAHACA" ≈ "CHILE MACHACADO"). El sustituto correcto
es la **`R.S.` que viene en la descripción**: es el código de producto del fabricante, así que
dos filas con la misma R.S. son el mismo producto en otra presentación.

### El barcode solo vive en un lugar

`PTYLX833F.IIM.IMUPC` está **100% vacío**; se auditaron las 340 columnas de IIM y ninguna
guarda código de barra. `Z_IIM`, `YTH`, `RMX`, `QCI` no sirven (desactualizadas o 0 filas).
`ORACLEBI.PRODUCTO` es catálogo de perfumería y su `COD_FEDURO` está hasheado.
→ **El código de barra solo existe en `SELLOUT.COD_PRODUCTO`.**

De IIM sí sirven: `IDESC`, `ICLAS` (`57` = material no vendible), `IREF01` (casa),
`IREF02` (sublínea; `MQ-MP` = promocional), `IREF03` (`COMES` / `PLV`). `ILIST` (precio)
está vacío → **el precio se deriva del sell-in real**: `SUM(ILEXTA)/SUM(ILQTY)` de `SIL`.

---

## 3. Fuentes por cadena

### Sell-in (Feduro → cliente), IBM AS400 / LX

`PTYLX833F.SIL` + `BACKUP.SIL26`, filtrando `ILID='IL' AND ILLTYP='R'`.
Campos: `ILCUST` (cliente), `ILPROD` (cod_feduro), `ILQTY`, `ILEXTA`.
Cabeceras en `SIH` (`SICUST`, `SIINVD`, `SINAM`…). **LX es read-only, sin excepción.**

### Plataforma de cadena, PDB REPORTS / schema `SELLOUT`

Usar las tablas **consolidadas**, no las `_SUCIA`:
`HISTORICO_VENTAS_CADENAS` + `HISTORICO_INVENTARIO_CADENAS`, unidas a `TIENDA_EXT`.
Cobertura observada: XTRA 2.485.353 filas / 63 tiendas / 2024-01→2026-07 · REY 1.385.482 /
209 / 2025-01→2026-07 · MACHETAZO 951.906 / 17 / 2024-01→2026-08. Las `_SUCIA` de XTRA solo
tenían 2 meses.

`SELLOUT.TIENDA_EXT` es el maestro de tiendas y **`ID_TIENDA` == `SICUST` de LX**
(validado nombre a nombre) → el cruce sell-in↔sell-out por tienda sale gratis para las
cadenas que estén ahí.

### Mapeo entidad legal LX → cadena

El nombre comercial casi no aparece en `SIH.SINAM`; hay que ir por razón social:

| Cadena | Razón social en LX |
| --- | --- |
| XTRA | `SUPERMERCADOS XTRA S.A.` (65 SICUST) |
| MACHETAZO | `COMPAÑIA GOLY, S.A.` / `CIA. GOLY` (21) |
| SUPER 99 | `IMPORTADORA RICAMAR, S.A.` (59) |
| SUPER CARNES | `IMPORTADORA VIRZI, S.A. (S/C n)` (15) |
| EL FUERTE | `TAMEK, S.A.` (8) |
| REY | **no se le vende a las tiendas** — ver abajo |

Excluir del denominador los pseudo-clientes que no son sucursales:
`\bNC\s*\)|\(PD\)|CEDI|BODEGA|CENCAL|ENVASADO|TRANSF`.

### REY es un caso aparte: se le vende al CEDI

`SICUST 208670` = `INMOBILIARIA DON ANTONIO (CEDI) SECO PACORA` es el cliente #1 de toda la
base. Los códigos `SM REY <sucursal>` solo tienen notas de crédito. Consecuencia:
**para Rey el sell-in no tiene grano de tienda** — la presencia sale solo de la plataforma
(reycom) y el sell-in va en una columna aparte `SE_LO_VENDEMOS_AL_CEDI` (SI/NO).
No se puede calcular sell-through por sucursal en Rey.

---

## 4. La lista ideal: surtido por formato de tienda

La lista del cliente **no es plana**: exige un surtido distinto por formato
(HIPERMERCADO / SUPERMERCADO / DESCUENTO / SUPER IND / MINISUPER / ABARROTERIA).
Medir todos los SKU contra todas las tiendas da un número falso y bajo — fue el error del
primer reporte (Rey "19.4%" cuando era 49.6%).

En el libro, esa lista vive en una hoja `IDEAL` con las columnas
`TCG · CATEGORÍA · EAN · DESCRIPCIÓN · HIPERMERCADO · SUPERMERCADO · DESCUENTO · SUPER IND · MINISUPER · ABARROTERIA`
(header en fila 3, datos desde la 4). `TCG` marca los infaltables duros.

El lookup desde la hoja de cadena, como array formula:

```excel
=IF(SUMPRODUCT((IDEAL!$C$4:$C$149&""=$C5&"")*(IDEAL!$F$4:$F$149="x"))>0,"X","")
```

`$F` = SUPERMERCADO. Para una cadena de un solo formato alcanza con una columna; **XTRA es
la única multiformato** (SX 17 · XM 17 · MA 15 · FE 11 · FA 2 sucursales) y ahí un solo
"IDEAL SUPERMERCADO" mide de más o de menos. El mapeo formato→columna ideal es
**criterio comercial, no dato**: se verificó que `RCM.CREF02`/`CREF03` de LX **no sirven**
(las 185 sucursales de las 6 cadenas son todas `TSUP`/`SSMC`). Hay que hacerlo explícito y
validarlo con el cliente.

Columna de control junto al ideal:

```excel
MATCH IDEAL = IF($E5="X",
                IF(COUNTIF($J5:$BS5,"X")>0,"SI","NO"),
                IF(COUNTIF($J5:$BS5,"X")>0,"NO DEBE ESTAR","OK"))
```

`SI` = lo exige y está · `NO` = lo exige y falta (la oportunidad) ·
`NO DEBE ESTAR` = está pero la lista no lo pide · `OK` = ni se exige ni está.

---

## 5. Hoja de cadena: la matriz

Una hoja por cadena. **Este layout está acordado con el usuario; no cambiarlo sin pedirlo.**

```
fila 1   A1  título "<CADENA> — PRODUCTOS INFALTABLES POR SUCURSAL"   14pt bold #1F3864
fila 2   A2  nota: "<N> productos INFALTABLES (TCG) · <M> sucursales · X = ... · fuente: ..."
             9pt italic #595959
fila 3   E3  leyenda de la lista ideal            8pt #595959
             (solo XTRA) A3 "FORMATO" + el código de formato sobre cada sucursal
fila 4       encabezados       fill #1F3864, font blanco bold 10, alto 130-150,
                               las sucursales con textRotation=90
filas 5..F   un producto por fila, ordenado por CATEGORIA y luego PRODUCTO
```

Columnas fijas, en este orden:

| Col | Contenido | Ancho |
| --- | --- | --- |
| A | CATEGORIA | 22 |
| B | PRODUCTO (la descripción **de la lista del cliente**, no la de la base) | 48 |
| C | EAN (texto, no número) | 15 |
| D | COD_FEDURO | 13 |
| E | IDEAL `<FORMATO>` (array formula contra la hoja IDEAL) | 17 |
| F | MATCH IDEAL | 21 |
| G | SUCURSALES = `COUNTIF(...)` — en REY es `SE_LO_VENDEMOS_AL_CEDI` | 13 |
| H, I | INV_CADENA / SUC_C-STOCK — **solo donde hay plataforma** | 13 |
| … | una columna por sucursal, ancho 4.4, `X` o vacío | 4.4 |
| última | CUMPL. % del producto | 14 |

Colores (formato condicional, no relleno fijo):

| Regla | Relleno | Fuente |
| --- | --- | --- |
| celda de sucursal = `"X"` | `#C6EFCE` | `#006100` |
| MATCH IDEAL = `"SI"` | `#C6EFCE` | `#006100` |
| MATCH IDEAL = `"NO"` | `#FFC7CE` | `#9C0006` |
| MATCH IDEAL = `"NO DEBE ESTAR"` | `#FFEB9C` | `#9C6500` |

`freeze_panes` en la primera columna de sucursal, fila 5. `auto_filter` sobre las columnas
fijas (`A4:G<F>`).

---

## 6. Listado de cumplimiento

Tres bloques derivados, todos **fórmulas** (nunca valores pegados) para que al reemplazar la
data se recalculen solos. Notación: `PRIM`/`ULT` = primera y última columna de sucursal,
`F` = última fila de producto.

### 6.1 Cumplimiento por producto — última columna de la matriz

```excel
=COUNTIF($<PRIM>5:$<ULT>5,"X")/COUNTA($<PRIM>$4:$<ULT>$4)      formato 0.0%
```

Qué responde: de todas las sucursales de la cadena, en qué % está este producto.
Es la lectura "un SKU, toda la cadena".

### 6.2 Cumplimiento por sucursal — dos filas al pie de la matriz

```
fila F+1   B: "PRODUCTOS POR SUCURSAL"
           por sucursal:  =COUNTIF(<col>5:<col><F>,"X")                        #,##0
fila F+3   A: "CUMPLIMIENTO % POR SUCURSAL"
           por sucursal:  =COUNTIF(<col>$5:<col>$<F>,"X")/COUNTA($B$5:$B$<F>)  0.0%
           en la col CUMPL. %, total de la cadena:
             =COUNTIF($<PRIM>$5:$<ULT>$<F>,"X")/(COUNTA($B$5:$B$<F>)*COUNTA($<PRIM>$4:$<ULT>$4))
```

Se deja la fila F+2 vacía como separador. Qué responde: cuántos infaltables tiene cada
tienda y qué % del portafolio exigido cubre. Es la lectura "una tienda, todo el portafolio",
y es la que ordena el plan de visitas.

### 6.3 Análisis por categoría (categoría × sucursal)

Bloque que arranca en la fila F+5 con un título y su encabezado en F+6:

```
CATEGORIA | SKU | X LOGRADOS | POSIBLES | FALTANTES | <una col por sucursal> | CUMPL. %
```

Una fila por categoría (en el mismo orden que la matriz) y una fila final `TOTAL CADENA`:

```excel
SKU          =COUNTIF($A$5:$A$<F>,$A<r>)
X LOGRADOS  {=SUMPRODUCT(($A$5:$A$<F>=$A<r>)*(<PRIM>$5:<ULT>$<F>="X"))}      matricial
POSIBLES     =$B<r>*COUNTA(<PRIM>$4:<ULT>$4)
FALTANTES    =$D<r>-$C<r>
por sucursal{=IF($B<r>=0,"",SUMPRODUCT(($A$5:$A$<F>=$A<r>)*(<col>$5:<col>$<F>="X"))/$B<r>)}
CUMPL. %     =IF($D<r>=0,"",$C<r>/$D<r>)
TOTAL        =SUM(B..) por columna, y CUMPL. % = $C<total>/$D<total>
```

El encabezado de sucursal de este bloque **no se escribe a mano**: es `=<col>$4`, así queda
atado al encabezado de la matriz y no se desincroniza si se renombra una tienda.
Sobre la rejilla de porcentajes por sucursal va una **escala de color** (no reglas
`cellIs`), que es lo que deja ver de un golpe qué categoría está floja en qué zona.

`FALTANTES` es la columna que se lleva a la reunión: son pares (tienda, SKU) accionables.

### 6.4 Cuidado con el denominador

Tal como están hoy, 6.1–6.3 dividen por **todos** los productos de la hoja × **todas** las
sucursales. Eso mide "cumplimiento sobre el portafolio completo". Si se quiere el
cumplimiento **sobre lo exigido a ese formato** hay que reemplazar `COUNTA($B$5:$B$<F>)` por
un `COUNTIF` sobre la columna del ideal, y en las cadenas multiformato usar la columna ideal
que corresponda a cada tienda. Son dos números distintos y **hay que decir cuál se está
reportando**: sobre lista completa Machetazo daba 52.4% y sobre lo disponible en Panamá 75.0%.

---

## 7. Hojas de stock (solo cadenas con plataforma)

Tres hojas por cadena con visibilidad. Todas son **espejos por fórmula** de la hoja `DATA
<CADENA>` (el extract crudo pegado tal cual): pegando data nueva encima, el resto se
actualiza sin tocar nada.

### `STOCK POR SUCURSAL <CADENA>` — una fila por tienda × SKU

XTRA: `Sucursal · Formato · Categoría · Subcategoría · EAN · Producto · Inventario (US$) ·
Inventario (unidades) · Días de cobertura · Estado de stock`.
El extract trae EAN y descripción en un solo campo, así que se parten:

```excel
EAN      =IFERROR(LEFT('DATA XTRA'!E2,FIND("-",'DATA XTRA'!E2)-1),'DATA XTRA'!E2)
Producto =IFERROR(MID('DATA XTRA'!E2,FIND("-",'DATA XTRA'!E2)+1,300),'DATA XTRA'!E2)
Estado   =IF(H5=0,"Sin stock",IF(AND(I5<>"",I5<15),"Stock bajo","Con stock"))
```

REY: `Código tienda · Sucursal · Categoría · Grupo de artículos · UPC · Descripción · Marca ·
Stock (unidades) · Costo unitario · Valor inventario · Venta prom. mensual · Meses de
cobertura · En tránsito · Estado de stock`. La tienda viene como `1234 - NOMBRE` y se parte
igual. Toda la fila va **guardada contra filas vacías** del extract:

```excel
=IF('DATA REY'!$P2="","", ... )
Valor inventario =IF($H5="","",$H5*$I5)
```

**El umbral de "crítico" cambia por cadena porque la unidad de cobertura cambia**: XTRA
reporta días (<15 = stock bajo), Rey reporta meses (<1 = crítico), Machetazo días
(<15 crítico, 30+ sano). No unificarlos a ciegas.

### `RESUMEN STOCK <CADENA>` — una fila por sucursal

Puro `SUMIFS`/`COUNTIFS` contra la hoja anterior (o directo contra `DATA` si no hay hoja
intermedia, como en Machetazo):

| Cadena | Columnas |
| --- | --- |
| XTRA | Sucursal · Formato · Inventario US$ · Inventario und · SKU con stock · SKU sin stock |
| REY | Código · Sucursal · Stock und · Valor inventario · En tránsito · SKU sin stock · SKU crítico (<1 mes) · SKU sanos |
| MACHETAZO | Sucursal · Stock und · Stock US$ · Venta últ. 30 días US$ · En tránsito · SKU surtidos · SKU sin stock · SKU crítico (<15 días) · SKU sanos (30+ días) |

### Formatos numéricos

| Tipo | Formato |
| --- | --- |
| Moneda (detalle) | `"$"#,##0.00;\("$"#,##0.00\);"-"` |
| Moneda (resumen) | `"$"#,##0;\("$"#,##0\);"-"` |
| Unidades | `#,##0;\(#,##0\);"-"` |
| Conteos que se ocultan en cero | `#,##0;;"-"` |
| Cobertura | `#,##0.0;;"-"` |
| Porcentajes | `0.0%` |
| Códigos de tienda / EAN | `@` (texto, si no Excel se come los ceros) |

El `"-"` de la tercera sección evita la sábana de ceros en las grillas dispersas.

---

## 8. Cómo replicarlo para otra casa

1. **Identificar la casa** en `SELLOUT.CASA` / prefijo del `cod_feduro`, y sacar su catálogo
   vendible de `PTYLX833F.IIM` (`IPROD LIKE '<CASA>%'`, excluyendo `ICLAS='57'`).
2. **Cargar la lista del cliente** en la hoja `IDEAL` respetando las columnas de formato.
3. **Matchear EAN→cod_feduro** con la secuencia de la sección 2. Guardar el resultado en un
   CSV intermedio (`match_v2.csv`: `EAN, DESC, TIPO, FED, BAR, DESCDB`) — es el artefacto que
   permite auditar y rehacer el reporte sin re-consultar la base.
4. **Listar las sucursales de cada cadena**: `TIENDA_EXT` donde exista, razón social de LX
   donde no. Excluir pseudo-clientes y tiendas que no son punto de venta.
5. **Calcular presencia** por (producto, sucursal) según la sección 1.
6. **Escribir la matriz** con el layout de la sección 5.
7. **Agregar los bloques de cumplimiento** (sección 6) y, si hay plataforma, las hojas de
   stock (sección 7).
8. **Sacar aparte el listado de lo que no está en la base**, separando
   "el barcode existe pero no está ligado a un cod_feduro" (se liga) de
   "no existe ni en la base ni en LX" (alta de producto).

Scripts de referencia en `problema-express/mccormick-distribucion/_trabajo/`:
`agregado.py` (arma el libro preservando un archivo previo), `fila_204221.py` (calcula la
presencia de un producto suelto), `insertar_fila.py` (inserta una fila en el .xlsx sin
romper el formato), `Probe.java` + `q.sh` (consultas read-only a LX / REPORTS / ORACLEBI).

---

## 9. Trampas conocidas

**De datos**

- **No filtrar la plataforma por marca.** El portafolio incluye marcas que la cadena
  cataloga con su propio nombre (`FRENCHS`, `RED HOT`, `CATTLEMENS`, `STUBBS`). Filtrar por
  `MARCA LIKE '%CORMICK%'` perdió 15 UPC en Rey y 815 filas en Machetazo. **Filtrar siempre
  por código de barra.**
- **Tiendas que no reportan.** Contando SKU distintos de cualquier marca por tienda: Machetazo
  mediana 2.562, XTRA 1.508, **Rey mediana 219 y 112 de 209 tiendas por debajo de 300**.
  Sin excluirlas inflan el gap con faltantes falsos (Rey pasa de 31% a 36% al sacarlas).
  Marcar `DATO` = CONFIABLE (≥300 SKU) / PARCIAL (100-299) / NO REPORTA (<100). **Una tienda
  que no reporta no puede entrar al listado de cumplimiento**: da 0% y ensucia el ranking.
- **El inventario es un stock, no un flujo**: tomar el último corte, nunca la suma de meses.
- **Extracts parciales**: si la plataforma solo trae N de los M SKU del portafolio, marcar
  `EN_EXTRACT_PLATAFORMA`; si no, "SKU fuera del extract" se confunde con "listado sin venta"
  (en XTRA generaba ~677 falsos "despachado sin venta POS").
- **CSV exportados a mano se truncan** (el de reycom cortaba en 50.000 filas). Preferir
  siempre la tabla ya cargada en la base.
- **Fuentes que envejecen**: un extract viejo puede no traer un UPC que la cadena sí maneja.
  Antes de reportar "0 sucursales" para un producto que sí se factura, buscarlo en el
  extract más nuevo. Pasó con `7411000204221`: `rey_inv.tsv` daba 0 y `DATA REY` daba 63.
  Contraste útil: si el producto tiene sell-in fuerte y presencia 0, sospechar de la fuente
  antes que del negocio.

**De herramienta**

- **`jt400` devuelve algunas columnas CHAR de LX como `byte[]`** (`rs.getObject` → `[B@...`).
  Fix: `if (o instanceof byte[]) v = new String((byte[]) o, "IBM280")`.
- **openpyxl: no copiar `cell._style` entre libros distintos** — los índices apuntan a la
  tabla de estilos del libro origen y el save explota con `IndexError` en `write_stylesheet`.
  Copiar `font / fill / border / alignment / number_format` objeto a objeto.
- **openpyxl no evalúa fórmulas**: al releer un libro para verificar, `COUNTIF` y compañía
  vuelven como texto. Para chequear cumplimiento hay que recalcular los conteos en Python
  sobre la grilla de `X`, no leer las celdas de fórmula.
- **openpyxl descarta al guardar** lo que no entiende: formato condicional x14 (barras de
  datos), webextensions, VML de comentarios, metadata de dynamic arrays. Si el libro ya tiene
  eso y hay que conservarlo, **editar el XML del .xlsx directamente** y reescribir solo las
  partes tocadas. Al correr filas: sumar 1 a toda referencia de fila `>= P` (salvo las
  calificadas con `'Hoja'!`), extender el `ref` de las fórmulas compartidas, correr
  `dimension` / `autoFilter` / `sqref` de formato condicional / `pane` / `selection` y los
  `definedNames` del libro, y **borrar `xl/calcChain.xml`** (Excel lo reconstruye) junto con
  su `Override` en `[Content_Types].xml` y su relación en `workbook.xml.rels`.
- **Al insertar filas, los bloques de cumplimiento son lo primero que se rompe en silencio**:
  quedan apuntando a `$B$5:$B$66` cuando la tabla ya llega a 67 y el porcentaje sale alto.
  Después de tocar el libro, verificar los tres bloques y los rangos del formato condicional.
