# Actitudes hacia la inmigración y cohesión social en Europa

Proyecto de Ciencia de Datos **reproducible** sobre las actitudes hacia la
inmigración en catorce países europeos entre 2002 y 2023, a partir de la
Encuesta Social Europea (ESS).

**Autora:** Pamela Valembois Madrigal
**Módulo 8 — Visualización de datos y Reproducibilidad**
Máster en Behavioral Data Science · Universitat de Barcelona
Docentes: Mireia Ribera y David Leiva

---

## Objetivos del proyecto

**Objetivo principal.** Proporcionar al equipo de análisis de un observatorio de
migraciones europeo una herramienta que permita describir y comparar la evolución
de las actitudes hacia la inmigración en catorce países europeos a lo largo de dos
décadas, identificando los patrones comunes, las divergencias nacionales y los
segmentos de población que las sustentan.

**Objetivos específicos.**

1. Situar la trayectoria de cada país en el contexto europeo.
2. Determinar si el conjunto de países converge o diverge.
3. Caracterizar los segmentos sociodemográficos asociados a cada posición.
4. Establecer en qué medida las actitudes migratorias se vinculan con indicadores
   más amplios de cohesión social.

Estos objetivos delimitan también el alcance: el proyecto describe asociaciones
observadas en muestras transversales repetidas, sin pretensión de inferencia
causal ni de predicción.

---

## Cómo reproducir el proyecto

> **Abre siempre el proyecto desde `m8_reto2.Rproj`** (RStudio: *File → Open
> Project*). El paquete `here` ancla la raíz del proyecto en ese fichero. Si abres
> los scripts sueltos, las rutas relativas no resolverán.
>
> **No hay ninguna referencia a directorios locales** en todo el repositorio.

```r
# 1. Instalar dependencias (solo la primera vez)
install.packages(c("here", "haven", "labelled", "dplyr", "tidyr", "readr",
                   "forcats", "ggplot2", "psych", "skimr", "naniar",
                   "knitr", "rmarkdown", "flexdashboard", "plotly", "crosstalk"))

# Para compilar el informe en PDF hace falta LaTeX. Si no lo tienes:
install.packages("tinytex"); tinytex::install_tinytex()

# 2. Reproducirlo todo de una vez (3-6 minutos)
source("render_todo.R")
```

`render_todo.R` comprueba primero que estén todos los paquetes y después ejecuta
la cadena completa. Si prefieres ir paso a paso:

```r
source(here::here("1_datos", "2_codigo", "01_importar_depurar.R"))
source(here::here("1_datos", "2_codigo", "02_eda.R"))

rmarkdown::render(here::here("2_dashboard", "codigo", "dashboard.Rmd"),
                  output_file = "dashboard.html", output_dir = here::here("2_dashboard"))
rmarkdown::render(here::here("3_informe", "codigo", "informe.Rmd"),
                  output_file = "informe.pdf", output_dir = here::here("3_informe"))
rmarkdown::render(here::here("4_presentacion", "codigo", "presentacion.Rmd"),
                  output_file = "presentacion.html", output_dir = here::here("4_presentacion"))
```

---

## Estructura del repositorio

```
.
├── m8_reto2.Rproj                  # ancla del proyecto: ábrelo desde aquí
├── .here                           # ancla alternativa para el paquete here
├── render_todo.R                   # reproduce el proyecto entero de una vez
├── README.md
│
├── 1_datos/
│   ├── 1_original/                 # datos de origen, NUNCA se modifican
│   │   ├── Datafile-subset.sav
│   │   └── Datafile-subset codebook.html
│   ├── 2_codigo/
│   │   ├── 00_comun.R              # paleta, tema, etiquetas y funciones comunes
│   │   ├── 01_importar_depurar.R   # importación, depuración, variables derivadas
│   │   └── 02_eda.R                # análisis exploratorio y las 5 figuras (G1-G5)
│   ├── 3_depurada/
│   │   └── ess_clean.rds           # generado por el script 01
│   └── 4_salidas/
│       ├── figuras/                # PNG generados por el script 02
│       └── tablas/                 # CSV agregados: la única fuente de cifras
│
├── 2_dashboard/
│   ├── codigo/dashboard.Rmd
│   └── dashboard.html              # HTML autónomo: se abre sin necesidad de R
│
├── 3_informe/
│   ├── codigo/informe.Rmd
│   └── informe.pdf
│
├── 4_presentacion/
│   ├── codigo/presentacion.Rmd
│   └── presentacion.html
│
└── 5_documentacion/
    ├── diccionario_campos_ESS.xlsx
    └── Informe_M8_Reto1.docx       # el diseño que este repositorio implementa
```

### Por qué esta organización

La separación entre `1_original/` y `3_depurada/` es deliberada: los datos
originales se tratan como **inmutables** y toda transformación queda registrada
en código, de modo que el fichero procesado siempre puede regenerarse desde cero.

El flujo de dependencias es estrictamente unidireccional:

```
01_importar_depurar.R  ->  ess_clean.rds
02_eda.R               ->  figuras (.png) y tablas agregadas (.csv)
dashboard.Rmd | informe.Rmd | presentacion.Rmd   (leen esas tablas)
```

Las tres salidas finales **leen las mismas tablas agregadas y ninguna recalcula
las medias por su cuenta**. Esa restricción es intencionada: hace estructuralmente
imposible que el dashboard, el informe y la presentación muestren cifras distintas
del mismo indicador. Por el mismo motivo, la paleta, los nombres de los países y
la función de media ponderada viven en un único fichero, `00_comun.R`, que cargan
los cuatro.

---

## Los datos

Extracto propio de la Encuesta Social Europea, construido con el *Data Wizard* del
portal del ESS.

| | |
|---|---|
| **Observaciones** | 290.398 |
| **Variables** | 49 |
| **Países** | 14 (los presentes en las 11 rondas) |
| **Rondas** | 1 a 11 (2002 – 2023/24) |
| **Unidad** | Persona entrevistada |
| **Fichero** | `.sav` de SPSS, 44 MB |

**Países:** Alemania, Bélgica, Eslovenia, España, Finlandia, Francia, Hungría,
Irlanda, Noruega, Países Bajos, Polonia, Portugal, Suecia y Suiza.

### Criterio de selección

Se incluyen únicamente los países presentes en **las once rondas**, de modo que la
matriz país × ronda no tiene huecos y toda comparación temporal se hace sobre el
mismo conjunto de países.

### Ediciones utilizadas

Los ficheros del ESS se corrigen y reeditan con posterioridad a su publicación,
por lo que la reproducibilidad exige fijar la edición concreta de cada ronda. El
extracto combina, por ejemplo, la edición 6.7 de la ronda 1 con la 4.2 de la 11.

| Ronda | Edición | DOI | Modo |
|---|---|---|---|
| ESS1 | 6.7 | 10.21338/ess1e06_7 | Presencial |
| ESS2 | 3.6 | 10.21338/ess2e03_6 | Presencial |
| ESS3 | 3.7 | 10.21338/ess3e03_7 | Presencial |
| ESS4 | 4.6 | 10.21338/ess4e04_6 | Presencial |
| ESS5 | 3.6 | 10.21338/ess5e03_6 | Presencial |
| ESS6 | 2.7 | 10.21338/ess6e02_7 | Presencial |
| ESS7 | 2.3 | 10.21338/ess7e02_3 | Presencial |
| ESS8 | 2.3 | 10.21338/ess8e02_3 | Presencial |
| ESS9 | 3.3 | 10.21338/ess9e03_3 | Presencial |
| ESS10 | 3.3 | 10.21338/ess10e03_3 | Presencial |
| ESS10SC | 3.2 | 10.21338/ess10sce03_2 | Autoadministrado |
| ESS11 | 4.2 | 10.21338/ess11e04_2 | Presencial |

---

## Depuración: incidencias detectadas y tratamiento

Todo lo siguiente está implementado y comentado en `01_importar_depurar.R`.

| Incidencia | Alcance | Tratamiento |
|---|---|---|
| `anweight` ausente al 100 % en las rondas 2 y 3 | 53.442 casos (18,4 %) | Reconstruido como `pspwght × pweight` (verificado en las 9 rondas donde ambos coexisten: r = 1,000000; diferencia máxima 1e-06) |
| `inwyys` / `inwyye` ausentes en las rondas 1, 2, 10 y 11 | 108.696 (37,4 %) | Eje temporal derivado de `essround` |
| `eisced` con códigos 0 y 55 fuera de la escala ordinal | 33.299 (11,5 %) | Recodificados a `NA` |
| `eduyrs` con valores implausibles, hasta 76 años | 209 (0,07 %) | Censurados por encima de 30 |
| `prob`, `stratum`, `psu` solo en rondas recientes | 73,2 % de `NA` | Descartadas |

**Variables de cobertura parcial** que se conservan pero no deben usarse en series
completas: `blgetmg` (no preguntada en las rondas 10 y 11) y `trstprt` (no
preguntada en la ronda 1). Por esto último el dashboard emplea `idx_conf_inst3`,
la versión de tres ítems del índice de confianza institucional, que sí tiene
cobertura en las once rondas.

**Aviso sobre el efecto de modo.** La ronda 10 de Alemania, España, Polonia y
Suecia se recogió mediante cuestionario autoadministrado y no por entrevista
presencial. Los cuatro países afectados presentan en 2020 una dispersión
sensiblemente mayor que los diez restantes, patrón compatible con un efecto de
modo. Los casos se conservan, pero ese punto debe leerse con cautela.

### Variables derivadas

`anio`, `grupo_edad`, `nivel_edu`, `sexo`, `habitat`, y los índices compuestos
`idx_actitud` (α = 0,844), `idx_permisividad` (α = 0,898), `idx_conf_inst`,
`idx_conf_inst3` e `idx_conf_interp`.

Se descartó **deliberadamente** crear una variable de macro-región
(Norte/Sur/Este/Oeste): sería una decisión a priori del analista y no un resultado
de los datos. El análisis se hace país a país, lo que además produce evidencia más
sólida.

### Notas metodológicas

- **Toda media va ponderada por `anweight`**, sin excepción. Es el peso que la
  documentación del ESS exige emplear al comparar entre países o entre rondas.
- Las correlaciones son de **Spearman** y no de Pearson: casi todas las variables
  sustantivas del ESS son ordinales.
- El **eje temporal no es regular** (la ronda 10 se retrasó por la pandemia y la 11
  corresponde a 2023/24), por lo que `anio` se trata siempre como escala
  cuantitativa y nunca como categoría equiespaciada.

---

## El dashboard

Implementa el diseño especificado en el Reto 1: dos vistas, siguiendo el mantra de
Shneiderman (panorámica primero, zoom y filtrado, detalle bajo demanda).

**Vista panorámica** — cuatro bandas horizontales, sin desplazamiento vertical:
tres cifras destacadas, y los cuatro gráficos que responden a las preguntas 1 a 4,
más la nota metodológica.

**Vista de exploración** — filtro de países que actúa simultáneamente sobre dos
gráficos vinculados, franja de foco y contexto sobre el eje temporal, y los
catorce pequeños múltiplos de la pregunta 5.

| | Pregunta | Gráfico |
|---|---|---|
| **G1** | ¿Cómo ha evolucionado la actitud por país y qué países se apartan? | Líneas múltiples: 11 países en gris, 3 destacados |
| **G2** | ¿Convergen o divergen los países? | Bandas de dispersión con la media superpuesta |
| **G3** | ¿Qué perfil se asocia a una actitud favorable? | Puntos conectados, ordenados por la magnitud del gradiente |
| **G4** | ¿Coinciden valoración y permisividad? | Dispersión a nivel país con recta de ajuste |
| **G5** | ¿Va el rechazo con desafección institucional? | Pequeños múltiplos, 14 paneles, dos series en escala 0–10 |

Se genera como **HTML autónomo**: se abre con doble clic, sin necesidad de tener R
instalado.

### Dos reglas que se cumplen en todo el dashboard

- **Cada país conserva su color** en las dos vistas y bajo cualquier filtro. El
  color acompaña a la entidad, nunca a su posición en el orden; por eso el vector
  de colores está fijado en `00_comun.R` con los catorce niveles declarados.
- **Ninguna información se transmite solo por color.** La etiqueta emergente nombra
  siempre el país y añade el tamaño muestral de la celda, que es lo que permite
  juzgar si una diferencia de tres décimas significa algo.

---

## Fuente

European Social Survey European Research Infrastructure (ESS ERIC). (2024).
*ESS rondas 1–11, ficheros integrados* [Conjunto de datos]. Sikt – Norwegian
Agency for Shared Services in Education and Research. https://ess.sikt.no
