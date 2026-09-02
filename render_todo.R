# =============================================================================
# M8 - Visualizacion de datos y Reproducibilidad | Reto 2
# Script maestro: reproduce el proyecto entero desde cero
#
# Autora: Pamela Valembois Madrigal
#
# Hay que abrir antes el proyecto desde 'm8_reto2.Rproj' (RStudio: File > Open Project)
# y despues ejecutar este fichero completo (Ctrl/Cmd + Shift + S, o 'Source').
#
# Cadena de ejecucion:
#   01_importar_depurar.R  ->  1_datos/3_depurada/ess_clean.rds
#   02_eda.R               ->  figuras (.png) y tablas agregadas (.csv)
#   dashboard.Rmd          ->  2_dashboard/dashboard.html
#   informe.Rmd            ->  3_informe/informe.pdf
#   presentacion.Rmd       ->  4_presentacion/presentacion.html
#
# Las tres salidas finales leen las mismas tablas agregadas que produce el
# script 02 y ninguna recalcula las medias por su cuenta, de modo que no pueden
# discrepar entre si.
#
# Tiempo aproximado: 3-6 minutos.
# =============================================================================

library(here)

cat("\nRaiz del proyecto:", here(), "\n\n")

# -----------------------------------------------------------------------------
# 0. COMPROBACION DE DEPENDENCIAS
# -----------------------------------------------------------------------------
# Se comprueban todos los paquetes antes de empezar.
paquetes <- c("here", "haven", "labelled", "dplyr", "tidyr", "readr", "forcats",
              "ggplot2", "psych", "knitr", "rmarkdown",
              "flexdashboard", "plotly", "crosstalk")
opcionales <- c("skimr", "naniar")   # solo para dos salidas del EDA

faltan <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltan) > 0) {
  stop("Faltan paquetes obligatorios. Instalalos con:\n\n",
       "  install.packages(c(", paste0('"', faltan, '"', collapse = ", "), "))\n",
       call. = FALSE)
}

faltan_opc <- opcionales[!vapply(opcionales, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltan_opc) > 0) {
  message("Aviso: sin ", paste(faltan_opc, collapse = " y "),
          " el EDA omite dos salidas auxiliares. El resto se genera igual.\n",
          "Para instalarlos: install.packages(c(",
          paste0('"', faltan_opc, '"', collapse = ", "), "))")
}

# El informe se compila en PDF, lo que exige una distribucion de LaTeX.
if (!nzchar(Sys.which("xelatex")) && !nzchar(Sys.which("pdflatex"))) {
  message("Aviso: no se encuentra LaTeX, asi que el informe en PDF fallara.\n",
          "Instalalo con:  install.packages('tinytex'); tinytex::install_tinytex()")
}

paso <- function(n, texto) cat("\n", strrep("=", 70), "\n", n, ". ", texto,
                               "\n", strrep("=", 70), "\n", sep = "")

# -----------------------------------------------------------------------------
# 1. IMPORTACION Y DEPURACION
# -----------------------------------------------------------------------------
paso(1, "Importacion y depuracion del extracto ESS")
source(here("1_datos", "2_codigo", "01_importar_depurar.R"), encoding = "UTF-8")

# -----------------------------------------------------------------------------
# 2. ANALISIS EXPLORATORIO Y FIGURAS
# -----------------------------------------------------------------------------
paso(2, "Analisis exploratorio, figuras y tablas agregadas")
source(here("1_datos", "2_codigo", "02_eda.R"), encoding = "UTF-8")

# -----------------------------------------------------------------------------
# 3. DASHBOARD
# -----------------------------------------------------------------------------
paso(3, "Dashboard (flexdashboard + plotly + crosstalk)")
rmarkdown::render(here("2_dashboard", "codigo", "dashboard.Rmd"),
                  output_file = "dashboard.html",
                  output_dir  = here("2_dashboard"),
                  quiet = TRUE)
cat("OK ->", here("2_dashboard", "dashboard.html"), "\n")

# -----------------------------------------------------------------------------
# 4. INFORME TECNICO
# -----------------------------------------------------------------------------
paso(4, "Informe tecnico con knitr (PDF)")

informe_ok <- tryCatch({
  rmarkdown::render(here("3_informe", "codigo", "informe.Rmd"),
                    output_file = "informe.pdf",
                    output_dir  = here("3_informe"),
                    quiet = TRUE)
  cat("OK ->", here("3_informe", "informe.pdf"), "\n")
  TRUE
}, error = function(e) {
  message("\nEl informe en PDF no se pudo compilar:\n  ", conditionMessage(e),
          "\n\nCasi siempre es LaTeX. Para reinstalar TinyTeX desde cero:",
          "\n  tinytex::uninstall_tinytex(force = TRUE)",
          "\n  unlink('~/Library/TinyTeX', recursive = TRUE)   # macOS",
          "\n  tinytex::install_tinytex()",
          "\n\nAlternativa sin LaTeX: cambiar en informe.Rmd la salida a",
          "\n  output: html_document\n",
          "\nSe continua con la presentacion.")
  FALSE
})

# -----------------------------------------------------------------------------
# 5. PRESENTACION
# -----------------------------------------------------------------------------
paso(5, "Presentacion con R Markdown (ioslides, HTML)")
rmarkdown::render(here("4_presentacion", "codigo", "presentacion.Rmd"),
                  output_file = "presentacion.html",
                  output_dir  = here("4_presentacion"),
                  quiet = TRUE)
cat("OK ->", here("4_presentacion", "presentacion.html"), "\n")

if (informe_ok) {
  paso("", "PROYECTO REPRODUCIDO POR COMPLETO")
} else {
  paso("", "CADENA COMPLETADA SALVO EL INFORME EN PDF (ver el aviso de arriba)")
}
