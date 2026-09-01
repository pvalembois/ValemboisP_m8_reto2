# =============================================================================
# M8 - Visualizacion de datos y Reproducibilidad | Reto 2
# Script 00: Elementos comunes (paleta, tema, etiquetas y funciones)
#
# Este fichero NO produce salidas. Lo cargan el script de EDA, el dashboard,
# el informe y la presentacion, de modo que las decisiones de codificacion
# visual esten definidas UNA sola vez y sean identicas en los cuatro sitios.
# Es la traduccion a codigo de la regla del Reto 1: "cada pais conserva su
# color en todos los graficos y en ambas vistas".
#
# Uso:  source(here::here("1_datos", "2_codigo", "00_comun.R"), encoding = "UTF-8")
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
})

# -----------------------------------------------------------------------------
# 1. PALETA FUNCIONAL
# -----------------------------------------------------------------------------
# Colores validados en el Reto 1 para contraste sobre fondo claro y para
# separacion suficiente en deuteranopia y protanopia.
AZUL    <- "#2a78d6"   # color primario
NARANJA <- "#eb6834"   # primer acento
VERDE   <- "#1baf7a"   # segundo acento
GRIS    <- "#cfcec9"   # contexto (series no destacadas)
TINTA   <- "#0b0b0b"   # texto principal
SUAVE   <- "#52514e"   # texto secundario
LINEA   <- "#e8e7e3"   # rejilla

# Rampa ORDINAL para el nivel educativo: un solo tono, de claro a oscuro.
# La luminosidad se percibe como ordenada, de modo que el canal visual
# reproduce la estructura del dato (correspondencia estructural de Bertin).
ORD <- c(Bajo = "#86b6ef", Medio = "#2a78d6", Alto = "#104281")

# -----------------------------------------------------------------------------
# 2. IDENTIDAD CROMATICA DE LOS PAISES
# -----------------------------------------------------------------------------
# El color acompana a la ENTIDAD, nunca a su posicion en el orden. Al fijar el
# vector aqui, cualquier filtro que reduzca el numero de series conserva el
# color de las supervivientes, tal como exige el diseno del Reto 1.
#
# ADVERTENCIA ASUMIDA: catorce tonos simultaneos exceden el limite de
# discriminacion cromatica fiable. Por eso (a) la vista panoramica representa
# once paises en gris y destaca solo tres, y (b) en la vista de exploracion
# ninguna informacion se transmite unicamente por color: la etiqueta emergente
# nombra siempre el pais. La base es la paleta cualitativa "muted" de Paul Tol,
# disenada para daltonismo, mas los tres acentos del proyecto (ES, HU, PT).
PAIS_COLOR <- c(
  BE = "#332288", CH = "#88CCEE", DE = "#117733", ES = "#2a78d6",
  FI = "#999933", FR = "#DDCC77", HU = "#eb6834", IE = "#CC6677",
  NL = "#882255", NO = "#AA4499", PL = "#6699CC", PT = "#1baf7a",
  SE = "#661100", SI = "#44AA99"
)

# Nombres legibles. Se usan en etiquetas, leyendas y tooltips; el codigo ISO de
# dos letras se conserva como clave interna porque es el que trae el fichero.
#
# Los acentos se escriben con secuencias de escape Unicode y no con el
# caracter literal. El motivo es de reproducibilidad: un
# fichero .R con caracteres no ASCII se interpreta segun la configuracion
# regional de la maquina que lo ejecuta, y falla en entornos con locale C o
# Latin-1. Con las secuencias de escape el fichero es ASCII puro y produce
# exactamente el mismo texto en cualquier sistema.
PAIS_NOMBRE <- c(
  BE = "B\u00e9lgica",      CH = "Suiza",     DE = "Alemania",  ES = "Espa\u00f1a",
  FI = "Finlandia",     FR = "Francia",   HU = "Hungr\u00eda", IE = "Irlanda",
  NL = "Pa\u00edses Bajos", NO = "Noruega",   PL = "Polonia",   PT = "Portugal",
  SE = "Suecia",        SI = "Eslovenia"
)

# Los tres paises que se destacan en la vista panoramica: Hungria por ser el
# unico caso descendente, Portugal y Espana por ser los ascensos mas marcados.
DESTACADOS <- c("HU", "PT", "ES")

# -----------------------------------------------------------------------------
# 3. TEMA GRAFICO
# -----------------------------------------------------------------------------
# Aplica el principio de simplicidad: se elimina todo elemento que no transporte
# informacion (rejilla densa, bordes de eje, sombras, degradados).
tema <- theme_minimal(base_size = 10) +
  theme(panel.grid.minor   = element_blank(),
        panel.grid.major.x = element_blank(),
        panel.grid.major.y = element_line(colour = LINEA, linewidth = .3),
        plot.title     = element_text(face = "bold", size = 12.5, colour = TINTA),
        plot.subtitle  = element_text(size = 8.4, colour = SUAVE),
        plot.title.position = "plot",
        axis.title     = element_text(size = 9, colour = SUAVE),
        legend.position = "top")

# -----------------------------------------------------------------------------
# 4. FUNCIONES DE AGREGACION
# -----------------------------------------------------------------------------
# Toda media del proyecto va ponderada por anweight, el peso que la
# documentacion del ESS exige emplear al comparar entre paises o entre rondas.
# Centralizar el calculo aqui garantiza que ninguna cifra del dashboard, del
# informe o de la presentacion se calcule por otro camino.

#' Media ponderada de una variable por los grupos indicados
#'
#' @param datos   data frame con la columna de peso 'anweight'
#' @param var     nombre (sin comillas) de la variable a promediar
#' @param ...     variables de agrupacion
#' @return tibble con las variables de agrupacion, la media y el n de la celda
media_ponderada <- function(datos, var, ...) {
  datos |>
    filter(!is.na({{ var }})) |>
    group_by(...) |>
    summarise(media = weighted.mean({{ var }}, anweight),
              n     = dplyr::n(),
              .groups = "drop")
}

#' Anade el nombre legible del pais a partir del codigo ISO
con_nombre_pais <- function(datos, col = cntry) {
  datos |> mutate(pais = unname(PAIS_NOMBRE[as.character({{ col }})]))
}

# Los once anios de referencia del extracto. El intervalo NO es regular: la
# ronda 10 se retraso por la pandemia y la 11 se recogio en 2023/24. 'anio'
# debe tratarse siempre como escala cuantitativa, nunca como categoria
# equiespaciada, o la pendiente del tramo final quedaria distorsionada.
ANIOS <- c(2002, 2004, 2006, 2008, 2010, 2012, 2014, 2016, 2018, 2020, 2023)
