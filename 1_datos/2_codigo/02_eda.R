# =============================================================================
# M8 - Visualizacion de datos y Reproducibilidad | Reto 2
# Script 02: Analisis Exploratorio de Datos (EDA) y figuras del proyecto
#
#   1. Descripcion global del conjunto y de cada campo
#   2. Estadisticos descriptivos univariantes
#   3. Valores ausentes y casos completos
#   4. Distribuciones
#   5. Outliers
#   6. Fiabilidad de los indices compuestos (alfa de Cronbach)
#   7. Relaciones bivariantes (Spearman) y multicolinealidad
#   8. Los cinco graficos del dashboard (G1 a G5)
#
# Entrada: 1_datos/3_depurada/ess_clean.rds  (de 01_importar_depurar.R)
#          1_datos/1_original/Datafile-subset.sav (para los outliers PRE-depuracion)
# Salidas: 1_datos/4_salidas/figuras/*.png  y  1_datos/4_salidas/tablas/*.csv
#
# Nota: se usa la correlacion de Spearman.
# Casi todas las variables sustantivas del ESS son ordinales (escalas Likert de 0-10 y de 1-4).
# =============================================================================

library(here); library(dplyr); library(tidyr); library(ggplot2)
library(forcats); library(psych); library(readr)

# Paleta, tema, identidad cromatica de los paises y funciones de agregacion.
source(here("1_datos", "2_codigo", "00_comun.R"), encoding = "UTF-8")

ess   <- readRDS(here("1_datos", "3_depurada", "ess_clean.rds"))
crudo <- haven::read_sav(here("1_datos", "1_original", "Datafile-subset.sav"))

ess_num <- haven::zap_labels(ess)

FIG <- here("1_datos", "4_salidas", "figuras")
TAB <- here("1_datos", "4_salidas", "tablas")
dir.create(FIG, recursive = TRUE, showWarnings = FALSE)
dir.create(TAB, recursive = TRUE, showWarnings = FALSE)

# Grupos de variables usados a lo largo del script
focales   <- c("idx_actitud", "idx_permisividad")
items_10  <- c("imbgeco", "imueclt", "imwbcnt")
items_4   <- c("imsmetn", "imdfetn", "impcntr")
contexto  <- c("ppltrst", "pplfair", "pplhlp", "trstprl", "trstplt", "trstprt",
               "trstlgl", "trstplc", "trstep", "stfdem", "stfeco", "stfgov",
               "stflife", "happy")
sociodem  <- c("agea", "eduyrs", "eisced", "lrscale", "rlgdgr")


###############################################################################
# 1. DESCRIPCION GLOBAL DEL CONJUNTO
###############################################################################

cat("\n===== 1. ESTRUCTURA DEL CONJUNTO =====\n")
cat("Dimensiones:", nrow(ess), "filas x", ncol(ess), "columnas\n")
cat("Paises:", n_distinct(ess$cntry), "| Rondas:", n_distinct(ess$essround), "\n")

glimpse(ess[, 1:15])

if (requireNamespace("skimr", quietly = TRUE)) {
  resumen_skim <- skimr::skim(ess_num)
  print(resumen_skim)
  write_csv(as.data.frame(resumen_skim), file.path(TAB, "02_skim_global.csv"))
}

# Matriz de cobertura pais x ronda
cobertura <- ess |> count(cntry, anio) |> pivot_wider(names_from = anio, values_from = n)
print(as.data.frame(cobertura), row.names = FALSE)
write_csv(cobertura, file.path(TAB, "02_cobertura_pais_ronda.csv"))


###############################################################################
# 2. ESTADISTICOS DESCRIPTIVOS UNIVARIANTES
###############################################################################

descriptivos <- ess_num |>
  select(all_of(c(focales, items_10, items_4, contexto, sociodem))) |>
  pivot_longer(everything(), names_to = "variable", values_to = "valor") |>
  filter(!is.na(valor)) |>
  group_by(variable) |>
  summarise(
    n         = n(),
    media     = mean(valor),
    sd        = sd(valor),
    mediana   = median(valor),
    p25       = quantile(valor, .25),
    p75       = quantile(valor, .75),
    minimo    = min(valor),
    maximo    = max(valor),
    asimetria = psych::skew(valor),      
    curtosis  = psych::kurtosi(valor),
    .groups   = "drop"
  ) |>
  mutate(across(where(is.numeric), ~ round(.x, 2)))

cat("\n===== 2. DESCRIPTIVOS UNIVARIANTES =====\n")
print(as.data.frame(descriptivos), row.names = FALSE)
write_csv(descriptivos, file.path(TAB, "02_descriptivos.csv"))

# Los mismos descriptivos de la variable focal, desagregados por pais.
desc_pais <- ess |>
  filter(!is.na(idx_actitud)) |>
  group_by(cntry) |>
  summarise(n = n(),
            media_ponderada = weighted.mean(idx_actitud, anweight),
            media_simple    = mean(idx_actitud),
            sd              = sd(idx_actitud),
            mediana         = median(idx_actitud),
            .groups = "drop") |>
  mutate(across(where(is.numeric), ~ round(.x, 2))) |>
  arrange(desc(media_ponderada))

cat("\n--- Indice de actitud por pais ---\n")
print(as.data.frame(desc_pais), row.names = FALSE)
write_csv(desc_pais, file.path(TAB, "02_descriptivos_por_pais.csv"))
# La comparacion media_ponderada vs media_simple documenta cuanto altera el peso
# el resultado.


###############################################################################
# 3. VALORES AUSENTES Y CASOS COMPLETOS
###############################################################################

ausentes <- ess |>
  summarise(across(everything(), ~ mean(is.na(.x)) * 100)) |>
  pivot_longer(everything(), names_to = "variable", values_to = "pct_na") |>
  arrange(desc(pct_na)) |>
  mutate(pct_na = round(pct_na, 2))

cat("\n===== 3. VALORES AUSENTES =====\n")
print(as.data.frame(filter(ausentes, pct_na > 0)), row.names = FALSE)
write_csv(ausentes, file.path(TAB, "02_valores_ausentes.csv"))

# FIG 1 - Ausentes por variable
p1 <- ausentes |>
  filter(pct_na > 0.05) |>
  mutate(variable = fct_reorder(variable, pct_na),
         grupo = case_when(pct_na > 15 ~ "Critico (>15%)",
                           pct_na > 2  ~ "Atencion (2-15%)",
                           TRUE        ~ "Aceptable (<2%)")) |>
  ggplot(aes(pct_na, variable, fill = grupo)) +
  geom_col(width = .72) +
  geom_text(aes(label = sprintf("%.1f%%", pct_na)), hjust = -.15, size = 2.5, colour = SUAVE) +
  scale_fill_manual(values = c("Critico (>15%)" = NARANJA,
                               "Atencion (2-15%)" = AZUL,
                               "Aceptable (<2%)" = GRIS)) +
  scale_x_continuous(limits = c(0, 45), expand = expansion(mult = c(0, .02))) +
  labs(title = "Valores perdidos por variable",
       subtitle = "Tras la conversion automatica de los codigos de missing declarados en el fichero SPSS",
       x = "% de valores perdidos", y = NULL, fill = NULL) +
  tema
ggsave(file.path(FIG, "f1_missing.png"), p1, width = 7.2, height = 6.4, dpi = 200)

# Vista alternativa con naniar sobre las variables del nucleo del dashboard
nucleo <- c("idx_actitud", "idx_permisividad", "ppltrst", "trstprl", "stfdem",
            "agea", "eisced", "gndr", "domicil", "lrscale", "anweight")
if (requireNamespace("naniar", quietly = TRUE)) {
  p1b <- naniar::gg_miss_var(ess_num[, nucleo], show_pct = TRUE) +
    labs(title = "Valores ausentes en las variables seleccionadas para el dashboard") + tema
  ggsave(file.path(FIG, "f1b_missing_nucleo.png"), p1b, width = 7, height = 4, dpi = 200)
}

# Casos completos: cuantas filas sobreviven sin imputacion
n_comp <- sum(complete.cases(ess_num[, nucleo]))
cat("\n--- Casos completos (nucleo del dashboard) ---\n")
cat(n_comp, "de", nrow(ess), sprintf("(%.1f%%)\n", n_comp / nrow(ess) * 100))

# Cobertura por ronda: detecta variables no preguntadas en rondas concretas
cobertura_var <- ess |>
  group_by(essround) |>
  summarise(across(all_of(c("blgetmg", "trstprt", "lrscale", "trstep", "idx_actitud")),
                   ~ round(mean(!is.na(.x)) * 100, 1)), .groups = "drop")
cat("\n--- % de datos disponibles por ronda (variables de cobertura irregular) ---\n")
print(as.data.frame(cobertura_var), row.names = FALSE)
write_csv(cobertura_var, file.path(TAB, "02_cobertura_por_ronda.csv"))


###############################################################################
# 4. DISTRIBUCIONES
###############################################################################

# FIG 3a - Items de valoracion (escala 0-10)
p3a <- ess_num |>
  select(all_of(items_10)) |>
  pivot_longer(everything(), names_to = "v", values_to = "valor") |>
  filter(!is.na(valor)) |>
  count(v, valor) |>
  group_by(v) |> mutate(pct = n / sum(n) * 100) |> ungroup() |>
  mutate(v = recode(v, imbgeco = "Impacto en la economia",
                       imueclt = "Impacto en la vida cultural",
                       imwbcnt = "Mejor o peor lugar para vivir")) |>
  ggplot(aes(valor, pct)) +
  geom_col(fill = AZUL, width = .72) +
  facet_wrap(~ v) +
  scale_x_continuous(breaks = seq(0, 10, 2)) +
  labs(title = "Distribucion de los items de valoracion de la inmigracion",
       subtitle = "Escala 0-10 - rondas 1-11 agrupadas - distribuciones unimodales con leve asimetria negativa",
       x = "Escala 0-10", y = "% de respuestas") +
  tema
ggsave(file.path(FIG, "f3a_distrib_0_10.png"), p3a, width = 9.4, height = 3.2, dpi = 200)

# FIG 3b - Items de permisividad (escala 1-4)
# Se representan como categorias al ser ordinales de 4 puntos y fuertemente concentrados.
# Promedio oculta la forma real.
p3b <- ess_num |>
  select(all_of(items_4)) |>
  pivot_longer(everything(), names_to = "v", values_to = "valor") |>
  filter(!is.na(valor)) |>
  count(v, valor) |>
  group_by(v) |> mutate(pct = n / sum(n) * 100) |> ungroup() |>
  mutate(v = recode(v, imsmetn = "Permitir: misma etnia",
                       imdfetn = "Permitir: distinta etnia",
                       impcntr = "Permitir: paises mas pobres"),
         valor = factor(valor, levels = 1:4,
                        labels = c("Muchos", "Algunos", "Pocos", "Ninguno"))) |>
  ggplot(aes(valor, pct)) +
  geom_col(fill = VERDE, width = .68) +
  facet_wrap(~ v) +
  labs(title = "Distribucion de los items de permisividad de entrada",
       subtitle = "Escala ordinal de 4 puntos - la concentracion en las categorias centrales desaconseja usar medias",
       x = NULL, y = "% de respuestas") +
  tema
ggsave(file.path(FIG, "f3b_distrib_1_4.png"), p3b, width = 9.4, height = 3.2, dpi = 200)


###############################################################################
# 5. OUTLIERS  (sobre el fichero antes de depurar)
###############################################################################

cat("\n===== 5. OUTLIERS =====\n")
cat("eduyrs > 30 anios:", sum(crudo$eduyrs > 30, na.rm = TRUE), "casos\n")
cat("eduyrs maximo observado:", max(crudo$eduyrs, na.rm = TRUE), "\n")
cat("agea minimo observado:", min(crudo$agea, na.rm = TRUE),
    "(el ESS entrevista a partir de 15 anios)\n")
cat("agea > 100:", sum(crudo$agea > 100, na.rm = TRUE), "casos\n")

p4 <- crudo |>
  select(eduyrs, agea) |>
  pivot_longer(everything(), names_to = "v", values_to = "valor") |>
  filter(!is.na(valor)) |>
  mutate(v = recode(v, eduyrs = "eduyrs - anios de educacion",
                       agea   = "agea - edad")) |>
  ggplot(aes(valor, v)) +
  geom_boxplot(fill = "#cde2fb", colour = AZUL, width = .5,
               outlier.colour = NARANJA, outlier.alpha = .35, outlier.size = .8) +
  labs(title = "Outliers e inconsistencias detectadas antes de la depuracion",
       subtitle = "eduyrs alcanza 76 anios de educacion; agea desciende a 14 pese al minimo teorico de 15",
       x = "Anios", y = NULL) +
  tema
ggsave(file.path(FIG, "f4_outliers.png"), p4, width = 8.4, height = 3.5, dpi = 200)


###############################################################################
# 6. FIABILIDAD DE LOS INDICES COMPUESTOS
###############################################################################

cat("\n===== 6. ALFA DE CRONBACH DE LOS INDICES =====\n")
alfa <- function(d, etiqueta) {
  a <- psych::alpha(na.omit(d), warnings = FALSE)$total$raw_alpha
  cat(sprintf("  %-38s alpha = %.3f  (n = %d)\n", etiqueta, a, nrow(na.omit(d))))
  tibble(indice = etiqueta, alpha = round(a, 3), n = nrow(na.omit(d)))
}
tabla_alfa <- bind_rows(
  alfa(ess_num[, items_10], "Actitud (imbgeco+imueclt+imwbcnt)"),
  alfa(5 - ess_num[, items_4], "Permisividad (items invertidos)"),
  alfa(ess_num[, c("trstprl","trstplt","trstprt","trstlgl")], "Confianza institucional"),
  alfa(ess_num[, c("ppltrst","pplfair","pplhlp")], "Confianza interpersonal")
)
write_csv(tabla_alfa, file.path(TAB, "02_alfa_cronbach.csv"))


###############################################################################
# 7. RELACIONES BIVARIANTES Y MULTICOLINEALIDAD  (Spearman)
###############################################################################

vars_cor <- c(focales, "ppltrst", "pplfair", "pplhlp", "trstprl", "trstplt",
              "trstprt", "trstlgl", "trstplc", "trstep", "stfdem", "stfeco",
              "stfgov", "stflife", "happy", "eduyrs", "eisced", "agea",
              "lrscale", "rlgdgr")

mat_cor <- cor(ess_num[, vars_cor], use = "pairwise.complete.obs", method = "spearman")
write.csv(round(mat_cor, 3), file.path(TAB, "02_matriz_spearman.csv"))

# Correlaciones de cada variable con la medida focal, ordenadas
cor_focal <- tibble(variable = vars_cor, rho = mat_cor[, "idx_actitud"]) |>
  filter(variable != "idx_actitud") |>
  arrange(desc(abs(rho))) |>
  mutate(rho = round(rho, 3))
cat("\n===== 7. CORRELACION (Spearman) CON EL INDICE DE ACTITUD =====\n")
print(as.data.frame(cor_focal), row.names = FALSE)
write_csv(cor_focal, file.path(TAB, "02_correlaciones_focal.csv"))

# --- Deteccion de multicolinealidad ------------------------------------------
# Se identifican los bloques de variables redundantes para retener un unico indicador por bloque.
pares <- which(abs(mat_cor) > .60 & upper.tri(mat_cor), arr.ind = TRUE)
multicol <- tibble(
  var_1 = rownames(mat_cor)[pares[, "row"]],
  var_2 = colnames(mat_cor)[pares[, "col"]],
  rho   = round(mat_cor[pares], 3)
) |> arrange(desc(abs(rho)))
cat("\n--- Pares con |rho| > 0,60: redundancia a resolver ---\n")
print(as.data.frame(multicol), row.names = FALSE)
write_csv(multicol, file.path(TAB, "02_multicolinealidad.csv"))

# FIG 5 - Matriz de correlaciones
p5 <- as.data.frame(as.table(mat_cor)) |>
  setNames(c("v1", "v2", "rho")) |>
  mutate(v1 = factor(v1, levels = vars_cor), v2 = factor(v2, levels = vars_cor)) |>
  filter(as.integer(v1) >= as.integer(v2)) |>
  ggplot(aes(v2, fct_rev(v1), fill = rho)) +
  geom_tile(colour = "#fcfcfb", linewidth = .4) +
  geom_text(aes(label = sub("^0\\.", ".", sprintf("%.2f", rho))), size = 2, colour = TINTA) +
  # Escala DIVERGENTE: dos polos y gris neutro en el cero.
  scale_fill_gradient2(low = "#104281", mid = "#f0efec", high = "#8f1f1e",
                       midpoint = 0, limits = c(-.9, .9)) +
  labs(title = "Correlaciones de Spearman entre las variables candidatas",
       subtitle = "Ninguna asociacion con la medida focal supera 0,33; los bloques oscuros senalan redundancia",
       x = NULL, y = NULL, fill = "rho") +
  tema +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 7),
        axis.text.y = element_text(size = 7),
        panel.grid = element_blank())
ggsave(file.path(FIG, "f5_corr.png"), p5, width = 8.6, height = 7.6, dpi = 200)


###############################################################################
# 8. LOS CINCO GRAFICOS DEL DASHBOARD
###############################################################################
# Cada figura responde a una de las cinco preguntas formuladas en el Reto 1.
# Se generan aqui en version estatica (PNG) y se reimplementan en el dashboard
# con plotly para anadirles interaccion. Las tablas agregadas que las sustentan
# se exportan.


# --- G1 (Pregunta 1): evolucion por pais, con destacado selectivo ------------
# Catorce series de color simultaneas sobrepasan el limite de discriminacion cromatica fiable
# Once paises van en gris neutro como contexto y tres se destacan con color.
serie <- ess |>
  media_ponderada(idx_actitud, anio, cntry) |>
  con_nombre_pais()
write_csv(serie, file.path(TAB, "02_serie_temporal_pais.csv"))

p_g1 <- ggplot() +
  geom_line(data = filter(serie, !cntry %in% DESTACADOS),
            aes(anio, media, group = cntry), colour = GRIS, linewidth = .45) +
  geom_line(data = filter(serie, cntry %in% DESTACADOS),
            aes(anio, media, colour = cntry), linewidth = .9) +
  geom_point(data = filter(serie, cntry %in% DESTACADOS),
             aes(anio, media, colour = cntry), size = 1.7) +
  geom_vline(xintercept = 2015, linetype = "dotted", colour = "#a8a7a2") +
  annotate("text", x = 2015.3, y = 6.9, label = "crisis de refugiados 2015",
           hjust = 0, size = 2.6, colour = SUAVE) +
  scale_colour_manual(values = PAIS_COLOR[DESTACADOS],
                      labels = PAIS_NOMBRE[DESTACADOS]) +
  # El anio va como escala cuantitativa: el intervalo entre rondas no es regular
  # (la ronda 10 se retraso por la pandemia y la 11 es de 2023/2024).
  scale_x_continuous(breaks = ANIOS) +
  labs(title = "La mayoria de Europa se abre; Hungria se cierra",
       subtitle = "Media ponderada del indice de actitud (0-10) - 14 paises presentes en las 11 rondas - los 11 restantes en gris",
       x = NULL, y = "Indice de actitud hacia la inmigracion (0-10)", colour = NULL) +
  tema + theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave(file.path(FIG, "f6_serie.png"), p_g1, width = 8.8, height = 5.2, dpi = 200)


# --- G2 (Pregunta 2): bandas de dispersion entre paises ----------------------
# Muestra la variabilidad en lugar del nivel. La banda exterior marca el rango
# entre el pais mas abierto y el mas restrictivo, la interior el recorrido
# intercuartilico, la linea central la media de las medias nacionales.
# El area ocupa una posicion baja en la jerarquia de Cleveland y McGill para
# estimar magnitudes exactas. Se busca juzgar la anchura, no el valor.
# Se anaden las cifras en los extremos de la serie.
dispersion <- serie |>
  group_by(anio) |>
  summarise(minimo = min(media), p25 = quantile(media, .25),
            media_eu = mean(media), p75 = quantile(media, .75),
            maximo = max(media), dt = sd(media),
            amplitud = max(media) - min(media), .groups = "drop")
write_csv(dispersion, file.path(TAB, "02_dispersion_entre_paises.csv"))

cat("\n===== G2. CONVERGENCIA O DIVERGENCIA =====\n")
print(as.data.frame(mutate(dispersion, across(where(is.numeric), ~ round(.x, 3)))),
      row.names = FALSE)

etq <- filter(dispersion, anio %in% range(ANIOS))
p_g2 <- ggplot(dispersion, aes(anio)) +
  geom_ribbon(aes(ymin = minimo, ymax = maximo), fill = AZUL, alpha = .13) +
  geom_ribbon(aes(ymin = p25, ymax = p75), fill = AZUL, alpha = .28) +
  geom_line(aes(y = media_eu), colour = "#104281", linewidth = 1) +
  geom_point(aes(y = media_eu), colour = "#104281", size = 1.6) +
  geom_text(data = etq, aes(y = maximo, label = sprintf("%.2f", maximo)),
            vjust = -.7, size = 2.7, colour = SUAVE) +
  geom_text(data = etq, aes(y = minimo, label = sprintf("%.2f", minimo)),
            vjust = 1.6, size = 2.7, colour = SUAVE) +
  scale_x_continuous(breaks = ANIOS, expand = expansion(mult = .06)) +
  labs(title = "Los paises europeos divergen: la banda se ensancha",
       subtitle = "Banda clara: minimo-maximo entre paises - banda oscura: recorrido intercuartilico - linea: media de las 14 medias nacionales",
       x = NULL, y = "Indice de actitud hacia la inmigracion (0-10)") +
  tema + theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave(file.path(FIG, "g2_dispersion.png"), p_g2, width = 7.4, height = 5.2, dpi = 200)


# --- G3 (Pregunta 3): gradiente educativo pais a pais ------------------------
# Se analiza por pais.
# Se elige el grafico de puntos conectados porque el objeto de interes es la distancia
# entre niveles dentro de cada pais.
gradiente <- ess |>
  filter(!is.na(nivel_edu)) |>
  media_ponderada(idx_actitud, cntry, nivel_edu) |>
  select(-n) |>
  pivot_wider(names_from = nivel_edu, values_from = media) |>
  mutate(diferencia = Alto - Bajo,
         monotono   = Alto > Medio & Medio > Bajo) |>
  con_nombre_pais() |>
  arrange(desc(diferencia))

cat("\n===== G3. GRADIENTE EDUCATIVO POR PAIS =====\n")
print(as.data.frame(mutate(gradiente, across(where(is.numeric), ~ round(.x, 2)))),
      row.names = FALSE)
cat("\nPaises con gradiente monotono:", sum(gradiente$monotono), "de", nrow(gradiente), "\n")
write_csv(gradiente, file.path(TAB, "02_gradiente_educativo.csv"))

p_g3 <- gradiente |>
  mutate(pais = fct_reorder(pais, diferencia)) |>
  pivot_longer(c(Bajo, Medio, Alto), names_to = "nivel", values_to = "media") |>
  mutate(nivel = factor(nivel, levels = c("Bajo", "Medio", "Alto"))) |>
  ggplot(aes(media, pais)) +
  geom_line(aes(group = pais), colour = "#dcdbd6", linewidth = 1.1) +
  geom_point(aes(colour = nivel), size = 3) +
  scale_colour_manual(values = ORD) +
  labs(title = "El gradiente educativo se cumple en los 14 paises, sin excepcion",
       subtitle = "Media ponderada del indice de actitud por nivel educativo - ordenado por la diferencia Alto - Bajo",
       x = "Indice de actitud hacia la inmigracion (0-10)", y = NULL,
       colour = "Nivel educativo") +
  tema + theme(panel.grid.major.y = element_blank(),
               panel.grid.major.x = element_line(colour = LINEA, linewidth = .3))
ggsave(file.path(FIG, "f7_gradiente.png"), p_g3, width = 8.6, height = 5.6, dpi = 200)


# --- G4 (Pregunta 4): valoracion frente a permisividad -----------------------
# A nivel individual, casi trescientas mil observaciones y coeficientes en
# torno a 0,30, el solapamiento de marcas produciria una nube sin estructura.
# Al agregar por pais la unidad de analisis pasa a ser el pais y las marcas se
# reducen a catorce. La recta de ajuste se incorpora como referencia
# para que la distancia a ella (las anomalias) se perciban facilmente.
dos_indices <- ess |>
  media_ponderada(idx_actitud, cntry) |>
  rename(actitud = media, n_actitud = n) |>
  left_join(ess |> media_ponderada(idx_permisividad, cntry) |>
              rename(permisividad = media) |> select(cntry, permisividad),
            by = "cntry") |>
  con_nombre_pais() |>
  mutate(rank_actitud      = rank(-actitud),
         rank_permisividad = rank(-permisividad),
         desfase           = rank_permisividad - rank_actitud)
write_csv(dos_indices, file.path(TAB, "02_dos_indices_pais.csv"))

rho_pais <- cor(dos_indices$actitud, dos_indices$permisividad, method = "spearman")
cat("\n===== G4. VALORACION FRENTE A PERMISIVIDAD =====\n")
cat("Correlacion de Spearman a nivel pais: rho =", round(rho_pais, 3), "\n")
print(as.data.frame(mutate(dos_indices, across(where(is.numeric), ~ round(.x, 2)))),
      row.names = FALSE)

p_g4 <- ggplot(dos_indices, aes(actitud, permisividad)) +
  geom_smooth(method = "lm", formula = y ~ x, se = FALSE,
              colour = GRIS, linewidth = .8) +
  geom_point(aes(colour = cntry), size = 3.2) +
  geom_text(aes(label = pais), vjust = -1.05, size = 2.7, colour = SUAVE) +
  scale_colour_manual(values = PAIS_COLOR, guide = "none") +
  scale_x_continuous(expand = expansion(mult = .09)) +
  scale_y_continuous(expand = expansion(mult = .11)) +
  labs(title = "Valorar bien la inmigracion no es lo mismo que querer admitir mas",
       subtitle = sprintf("Medias ponderadas por pais, rondas 1-11 agrupadas - rho de Spearman = %.3f - la recta es la tendencia de ajuste",
                          rho_pais),
       x = "Indice de actitud (0-10)", y = "Indice de permisividad (1-4)") +
  tema
ggsave(file.path(FIG, "g4_dos_indices.png"), p_g4, width = 7.6, height = 5.6, dpi = 200)


# --- G5 (Pregunta 5): pequenos multiplos, actitud y confianza institucional ---
# Se emplea idx_conf_inst3 (parlamento, politicos y sistema legal)
# Manteniendo iguales los ejes de todos los paneles, la comparacion entre
# paises se convierte en una comparacion de posicion sobre una escala comun,
# que es muy precisa segun la jerarquia de Cleveland y McGill. Ambas series
# comparten la escala 0-10, asi que se representan en un unico eje vertical.
cohesion <- ess |>
  media_ponderada(idx_actitud, anio, cntry) |>
  rename(actitud = media) |> select(-n) |>
  left_join(ess |> media_ponderada(idx_conf_inst3, anio, cntry) |>
              rename(conf_inst = media) |> select(anio, cntry, conf_inst),
            by = c("anio", "cntry")) |>
  con_nombre_pais()
write_csv(cohesion, file.path(TAB, "02_cohesion_institucional.csv"))

# Correlacion temporal dentro de cada pais: cuanto se mueven juntas las dos
# series a lo largo de las once rondas.
cor_cohesion <- cohesion |>
  group_by(cntry, pais) |>
  summarise(rho = cor(actitud, conf_inst, method = "spearman"), .groups = "drop") |>
  arrange(desc(rho))
cat("\n===== G5. ACTITUD Y CONFIANZA INSTITUCIONAL: CORRELACION TEMPORAL POR PAIS =====\n")
print(as.data.frame(mutate(cor_cohesion, rho = round(rho, 3))), row.names = FALSE)
write_csv(cor_cohesion, file.path(TAB, "02_cor_cohesion_por_pais.csv"))

# Los paneles se ordenan por el nivel medio de actitud del pais, de modo que la
# posicion dentro de la rejilla aporte informacion ademas de la de cada panel.
orden_paneles <- cohesion |>
  group_by(pais) |> summarise(m = mean(actitud), .groups = "drop") |>
  arrange(desc(m)) |> pull(pais)

p_g5 <- cohesion |>
  pivot_longer(c(actitud, conf_inst), names_to = "indicador", values_to = "valor") |>
  mutate(pais = factor(pais, levels = orden_paneles),
         indicador = factor(indicador, levels = c("actitud", "conf_inst"),
                            labels = c("Actitud hacia la inmigracion",
                                       "Confianza institucional"))) |>
  ggplot(aes(anio, valor, colour = indicador)) +
  geom_line(linewidth = .65) +
  geom_point(size = .9) +
  facet_wrap(~ pais, ncol = 5) +
  scale_colour_manual(values = c("Actitud hacia la inmigracion" = AZUL,
                                 "Confianza institucional" = NARANJA)) +
  scale_x_continuous(breaks = c(2002, 2012, 2023)) +
  labs(title = "Rechazo a la inmigracion y desafeccion institucional no siempre van juntos",
       subtitle = "Medias ponderadas, ambas en escala 0-10 y con ejes identicos en los 14 paneles - ordenados por nivel medio de actitud",
       x = NULL, y = "Escala 0-10", colour = NULL) +
  tema + theme(panel.grid.major.x = element_line(colour = LINEA, linewidth = .3),
               strip.text = element_text(size = 8, colour = TINTA))
ggsave(file.path(FIG, "g5_multiples.png"), p_g5, width = 9.6, height = 6.2, dpi = 200)


# --- Perfil sociodemografico por pais (base de la vista de exploracion) ------
# Media ponderada del indice de actitud para cada nivel de cada segmentador,
# dentro de cada pais y agrupando las once rondas.
# Permite comprobar en el dashboard si el patron educativo se sostiene al cambiar de segmento.
perfil_dim <- function(datos, var, dimension) {
  datos |>
    filter(!is.na({{ var }}), !is.na(idx_actitud)) |>
    group_by(cntry, nivel = as.character({{ var }})) |>
    summarise(media = weighted.mean(idx_actitud, anweight),
              n = dplyr::n(), .groups = "drop") |>
    mutate(dimension = dimension)
}

perfil <- bind_rows(
  perfil_dim(ess, nivel_edu,  "Nivel educativo"),
  perfil_dim(ess, grupo_edad, "Grupo de edad"),
  perfil_dim(ess, sexo,       "Sexo"),
  perfil_dim(ess, habitat,    "Habitat")
) |>
  con_nombre_pais() |>
  select(dimension, nivel, cntry, pais, media, n)
write_csv(perfil, file.path(TAB, "02_perfil_sociodemografico.csv"))

cat("\n===== PERFIL SOCIODEMOGRAFICO =====\n")
cat("Combinaciones pais x segmento exportadas:", nrow(perfil), "\n")


###############################################################################
# 9. CIFRAS DESTACADAS DEL DASHBOARD
###############################################################################
# Las tres cifras de la banda superior de la vista panoramica.
# La columna 'clave' es un identificador estable en ASCII. El dashboard, el
# informe y la presentacion buscan por ella.
cifras <- tibble(
  clave = c("media_2023", "cambio_2002_2023", "amplitud_2023"),
  cifra = c("Media europea 2023",
            "Cambio desde 2002",
            "Amplitud entre paises 2023"),
  valor = c(dispersion$media_eu[dispersion$anio == 2023],
            dispersion$media_eu[dispersion$anio == 2023] -
              dispersion$media_eu[dispersion$anio == 2002],
            dispersion$amplitud[dispersion$anio == 2023])
) |> mutate(valor = round(valor, 2))
cat("\n===== 9. CIFRAS DESTACADAS =====\n")
print(as.data.frame(cifras), row.names = FALSE)
write_csv(cifras, file.path(TAB, "02_cifras_destacadas.csv"))

cat("\n=== EDA COMPLETADO ===\n")
cat("Figuras en 1_datos/4_salidas/figuras/ - Tablas en 1_datos/4_salidas/tablas/\n")
