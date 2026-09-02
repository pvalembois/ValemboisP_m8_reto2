# =============================================================================
# M8 - Visualizacion de datos y Reproducibilidad | Reto 2
# Script 01: Importacion y depuracion del extracto ESS
#
# Autora  : Pamela Valembois Madrigal
# Fuente  : European Social Survey (ESS), rondas 1-11 (2002-2023/24)
# Extracto: 14 paises presentes en las 11 rondas x 49 variables
#
# Entrada : 1_datos/1_original/Datafile-subset.sav
# Salida  : 1_datos/3_depurada/ess_clean.rds
#
# Nota de reproducibilidad: no se usa ninguna ruta absoluta. Todas las rutas se
# construyen con el paquete 'here', que ancla la raiz del proyecto en el fichero
# m8_reto2.Rproj (o en el fichero .here).
# =============================================================================

library(here)      # rutas relativas robustas
library(haven)     # lectura de ficheros SPSS (.sav)
library(dplyr)     # manipulacion de datos
library(labelled)  # gestion de etiquetas de SPSS

# -----------------------------------------------------------------------------
# 1. IMPORTACION
# -----------------------------------------------------------------------------
# read_sav() con user_na = FALSE convierte los valores perdidos declarados en el fichero
# (77/88/99, 7/8/9, 999...) a NA. Las 36 variables sustantivas del extracto llevan
# esos rangos correctamente declarados en el .sav original.
ruta_datos <- here("1_datos", "1_original", "Datafile-subset.sav")

# Comprobacion explicita de la ruta
if (!file.exists(ruta_datos)) {
  stop(
    "No se encuentra el fichero de datos en:\n  ", ruta_datos,
    "\n\nComprueba que:",
    "\n  1. Se ha abierto el proyecto desde 'm8_reto2.Rproj' (RStudio: File > Open Project).",
    "\n     here() ancla la raiz en ese fichero. Sin el, busca desde el directorio actual.",
    "\n  2. El fichero .sav esta en '1_datos/1_original/' dentro de la raiz del proyecto.",
    "\n\nRaiz que here() esta usando ahora: ", here(),
    call. = FALSE
  )
}

ess_raw <- read_sav(ruta_datos)

stopifnot(nrow(ess_raw) == 290398, ncol(ess_raw) == 49)

# -----------------------------------------------------------------------------
# 2. DEPURACION
# -----------------------------------------------------------------------------

ess <- ess_raw |>

  # --- 2.1 Eliminar variables de diseno muestral inutilizables -----------------
  # prob, stratum y psu solo estan disponibles en las rondas recientes
  # (73,2% de NA en el conjunto). Solo serian necesarias para calcular errores
  # tipicos basados en el diseno. Como el proyecto es descriptivo,
  # se descartan para no arrastrar columnas casi vacias.
  select(-prob, -stratum, -psu) |>

  # --- 2.2 Reconstruir el peso de analisis (anweight) --------------------------
  # PROBLEMA: anweight falta al 100% en las rondas 2 y 3 (53.442 casos, 18,4%).
  # SOLUCION: la propia documentacion del ESS define anweight = pspwght * pweight.
  # Se ha verificado empiricamente en las 9 rondas donde existe.
  # Sin este arreglo seria imposible comparar rondas 2 y 3 con el resto.
  mutate(
    anweight = if_else(is.na(anweight), pspwght * pweight, anweight)
  ) |>

  # --- 2.3 Construir el eje temporal ------------------------------------------
  # PROBLEMA: inwyys / inwyye (ano de entrevista) faltan al 100% en las
  # rondas 1, 2, 10 y 11.
  # SOLUCION: derivar el ano de referencia a partir de essround.
  # El intervalo no es regular. Las rondas 1-9 son bienales, la ronda 10
  # se retraso por la pandemia (campo 2020-2022) y la 11 se recogio en 2023/24.
  # Se usa 'anio' como escala cuantitativa.
  mutate(
    anio = recode(as.numeric(essround),
                  `1` = 2002, `2` = 2004, `3`  = 2006, `4`  = 2008,
                  `5` = 2010, `6` = 2012, `7`  = 2014, `8`  = 2016,
                  `9` = 2018, `10` = 2020, `11` = 2023)
  ) |>

  # --- 2.4 Corregir outliers e inconsistencias --------------------------------
  mutate(
    # eduyrs: "anos de educacion a tiempo completo completados". El rango
    # observado llega a 76 anos, que es implausible. Se censuran como NA los valores
    # > 30 (209 casos, 0,07%).
    eduyrs = if_else(eduyrs > 30, NA_real_, eduyrs),

    # eisced: escala ordinal de 7 niveles educativos armonizados. Los codigos
    # 0 ("no armonizable") y 55 ("otro") se marcan como a NA (33.299 casos, 11,5%).
    eisced = if_else(eisced %in% c(0, 55), NA_real_, eisced)
  ) |>

  # --- 2.5 Variables derivadas -------------------------------------------------
  mutate(
    # Tramos etarios (ordinal).
    grupo_edad = cut(agea,
                     breaks = c(14, 29, 44, 59, 74, Inf),
                     labels = c("15-29", "30-44", "45-59", "60-74", "75+"),
                     right = TRUE),

    # Nivel educativo colapsado a 3 categorias a partir de eisced.
    nivel_edu = case_when(
      eisced %in% 1:2 ~ "Bajo",
      eisced %in% 3:4 ~ "Medio",
      eisced %in% 5:7 ~ "Alto",
      TRUE            ~ NA_character_
    ),
    nivel_edu = factor(nivel_edu, levels = c("Bajo", "Medio", "Alto")),

    # Sexo como factor legible.
    sexo = factor(gndr, levels = c(1, 2), labels = c("Hombre", "Mujer")),

    # Habitat de residencia a partir de domicil (5 niveles ordenados de mas
    # urbano a mas rural). Se etiqueta para poder usarlo como segmentador
    # legible en el dashboard.
    habitat = factor(domicil, levels = 1:5,
                     labels = c("Ciudad grande", "Periferia de ciudad",
                                "Ciudad peque\u00f1a", "Pueblo", "Campo")),

    # --- Indices compuestos ---------------------------------------------------
    # Todos verificados con alfa de Cronbach sobre el conjunto completo.
    # Se usa na.rm = FALSE : indice solo se calcula si la
    # persona respondio a los tres items, para que todas las medias del
    # dashboard descansen sobre la misma definicion del constructo.

    # Actitud hacia la inmigracion (0 = muy negativa, 10 = muy positiva).
    # alfa = 0,844 (n = 271.544)
    idx_actitud = rowMeans(cbind(imbgeco, imueclt, imwbcnt), na.rm = FALSE),

    # Permisividad de entrada. Los items originales van de 1 ("permitir muchos")
    # a 4 ("no permitir ninguno"): se invierten para que, igual que el indice
    # anterior, un valor alto signifique mayor apertura (1 = cerrado, 4 = abierto).
    # alfa = 0,898 (n = 277.654)
    idx_permisividad = rowMeans(cbind(5 - imsmetn, 5 - imdfetn, 5 - impcntr),
                                na.rm = FALSE),

    # Confianza institucional (0-10). alfa = 0,896 (n = 251.275)
    idx_conf_inst = rowMeans(cbind(trstprl, trstplt, trstprt, trstlgl),
                             na.rm = FALSE),

    # Confianza interpersonal (0-10). alfa = 0,754 (n = 287.674)
    idx_conf_interp = rowMeans(cbind(ppltrst, pplfair, pplhlp), na.rm = FALSE)
  )

# -----------------------------------------------------------------------------
# 3. AVISOS SOBRE VARIABLES DE COBERTURA PARCIAL
# -----------------------------------------------------------------------------
# Se conservan en el fichero, pero no deben usarse en graficos de serie completa:
#   - blgetmg  : no se pregunto en las rondas 10 y 11 (100% NA)
#   - trstprt  : no se pregunto en la ronda 1 (100% NA)
#   - inwyys / inwyye : ausentes en rondas 1, 2, 10 y 11
# El indice idx_conf_inst incluye trstprt, por lo que es NA en toda la ronda 1.
# Se construye una version de 3 items sin trstprt, que si tiene
# cobertura en las once rondas: es la que usa el dashboard (grafico G5).
ess <- ess |>
  mutate(
    idx_conf_inst3 = rowMeans(cbind(trstprl, trstplt, trstlgl), na.rm = FALSE)
  )

# -----------------------------------------------------------------------------
# 4. VERIFICACION Y GUARDADO
# -----------------------------------------------------------------------------
stopifnot(
  !any(is.na(ess$anweight)),          
  n_distinct(ess$cntry)    == 14,     # 14 paises
  n_distinct(ess$essround) == 11,     # 11 rondas
  n_distinct(ess$anio)     == 11,     # 11 anios distintos, sin colisiones
  max(ess$eduyrs, na.rm = TRUE) <= 30 # censura de eduyrs
)

dir.create(here("1_datos", "3_depurada"), showWarnings = FALSE, recursive = TRUE)
saveRDS(ess, here("1_datos", "3_depurada", "ess_clean.rds"))

cat("OK - fichero depurado:", nrow(ess), "filas x", ncol(ess), "variables\n")
cat("Guardado en:", here("1_datos", "3_depurada", "ess_clean.rds"), "\n")
