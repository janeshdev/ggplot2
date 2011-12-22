#' Build a plot with all the usual bits and pieces.
#' 
#' This function builds all grobs necessary for displaying the plot, and
#' stores them in a special data structure called a \code{\link{gtable}}.
#' This object is amenable to programmatic manipulation, should you want
#' to (e.g.) make the legend box 2 cm wide, or combine multiple plots into
#' a single display, preserving aspect ratios across the plots.
#'
#' @seealso \code{\link{print.ggplot}} and \code{link{benchplot}} for 
#'  for functions that contain the complete set of steps for generating
#'  a ggplot2 plot.
#' @return a \code{\link{gtable}} object
#' @keywords internal
#' @param plot plot object
#' @param data plot data generated by \code{\link{ggplot_build}}
#' @export
ggplot_gtable <- function(data) {

  plot <- data$plot
  panel <- data$panel
  data <- data$data
  theme <- plot_theme(plot)
  
  build_grob <- function(layer, layer_data) {
    dlply(layer_data, "PANEL", function(df) {
      panel_i <- match(df$PANEL[1], panel$layout$PANEL)
      layer$make_grob(df, scales = panel$ranges[[panel_i]], cs = plot$coord)
    }, .drop = FALSE)
  }

  # helper function return the position of panels in plot_table
  find_panel <- function(table) {
    summarize(subset(table$layout, grepl("^panel", name)),
      t = min(t), r = max(r), b = max(b), l = min(l))
  }

  # List by layer, list by panel
  geom_grobs <- Map(build_grob, plot$layer, data)

  plot_table <- facet_render(plot$facet, panel, plot$coordinates,
    plot_theme(plot), geom_grobs)

  # Title  
  title <- theme_render(theme, "plot.title", plot$options$title)
  title_height <- grobHeight(title) + 
    if (is.null(plot$options$title)) unit(0, "lines") else unit(0.5, "lines")
  
  plot_table <- gtable_add_rows(plot_table, title_height, pos = 0)
  plot_table <- gtable_add_grob(plot_table, title, name = "title",
    t = 1, b = 1, l = 2, r = -1)
  
  # Axis labels
  labels <- coord_labels(plot$coordinates, list(
    x = xlabel(panel, theme),
    y = ylabel(panel, theme)
  ))
  xlabel <- theme_render(theme, "axis.title.x", labels$x)
  ylabel <- theme_render(theme, "axis.title.y", labels$y)
  
  panel_dim <-  find_panel(plot_table)

  xlab_height <- grobHeight(xlabel) + 
    if (is.null(labels$x)) unit(0, "lines") else unit(0.5, "lines")
  plot_table <- gtable_add_rows(plot_table, xlab_height)
  plot_table <- gtable_add_grob(plot_table, xlabel, name = "xlab",
    l = panel_dim$l, r = panel_dim$r, t = -1)
  
  ylab_width <- grobWidth(ylabel) + 
    if (is.null(labels$y)) unit(0, "lines") else unit(0.5, "lines")
  plot_table <- gtable_add_cols(plot_table, ylab_width, pos = 0)
  plot_table <- gtable_add_grob(plot_table, ylabel, name = "ylab",
    l = 1, b = panel_dim$b, t = panel_dim$t)

  # Legends
  position <- theme$legend.position
  if (length(position) == 2) {
    coords <- position
    position <- "manual"
  }

  legend_box <- if (position != "none") {
    build_guides(plot$scales, plot$layers, plot$mapping, position, theme)
  } else {
    zeroGrob()
  }
  # here, use $width and $height for legend gtable.
  # grobWidth() and grobHeight() cannot work with it.
  legend_width <- legend_box$width
  legend_height <- legend_box$height
  if (is.zero(legend_box)) {
    position <- "none"
  } else {
    # these are a bad hack, since it modifies the contents fo viewpoint directly...
    legend_width <- legend_width + theme$legend.margin
    legend_height <- legend_height + theme$legend.margin
    # vp size = grob size. This enables justification in gtable.
    legend_box$childrenvp$parent$width <- legend_width
    legend_box$childrenvp$parent$height <- legend_height
    legend_box$childrenvp$parent$justification <- theme$legend.justification %||% "center"
    legend_box$childrenvp$parent$valid.just <- valid.just(theme$legend.justification)

    if (position == "manual") {
      # x and y are specified via theme$legend.position (i.e., coords)
      legend_box$childrenvp$parent$x <- unit(coords[1], "npc")
      legend_box$childrenvp$parent$y <- unit(coords[2], "npc")
    } else {
      # x and y are adjusted using justification of legend box (i.e., theme$legend.justification)
      legend_box$childrenvp$parent$x <- unit(legend_box$childrenvp$parent$valid.just[1], "npc")
      legend_box$childrenvp$parent$y <- unit(legend_box$childrenvp$parent$valid.just[2], "npc")
    }
  }

  panel_dim <-  find_panel(plot_table)
  # for align-to-device, use this:
  # panel_dim <-  summarize(plot_table$layout, t = min(t), r = max(r), b = max(b), l = min(l))
  
  if (position == "left") {
    plot_table <- gtable_add_cols(plot_table, legend_width, pos = 0)
    plot_table <- gtable_add_grob(plot_table, legend_box, 
      t = panel_dim$t, b = panel_dim$b, l = 1, r = 1, name = "guide-box")
  } else if (position == "right") {
    plot_table <- gtable_add_cols(plot_table, legend_width, pos = -1)
    plot_table <- gtable_add_grob(plot_table, legend_box, 
      t = panel_dim$t, b = panel_dim$b, l = -1, r = -1, name = "guide-box")
  } else if (position == "bottom") {
    plot_table <- gtable_add_rows(plot_table, legend_height, pos = -1)
    plot_table <- gtable_add_grob(plot_table, legend_box, 
      t = -1, b = -1, l = panel_dim$l, r = panel_dim$r, name = "guide-box")
  } else if (position == "top") {
    plot_table <- gtable_add_rows(plot_table, legend_height, pos = 0)
    plot_table <- gtable_add_grob(plot_table, legend_box, 
      t = 1, b = 1, l = panel_dim$l, r = panel_dim$r, name = "guide-box")
  } else if (position == "manual") {
    # should guide box expand whole region or region withoug margin?
    plot_table <- gtable_add_grob(plot_table, legend_box,
        t = panel_dim$t, b = panel_dim$b, l = panel_dim$l, r = panel_dim$r,
        clip = "off", name = "guide-box")
  }
  
  # Margins
  plot_table <- gtable_add_rows(plot_table, theme$plot.margin[1], pos = 0)
  plot_table <- gtable_add_cols(plot_table, theme$plot.margin[2])
  plot_table <- gtable_add_rows(plot_table, theme$plot.margin[3])
  plot_table <- gtable_add_cols(plot_table, theme$plot.margin[4], pos = 0)

  plot_table
}

#' Draw plot on current graphics device.
#'
#' @param x plot to display
#' @param newpage draw new (empty) page first?
#' @param vp viewport to draw plot in
#' @param ... other arguments not used by this method
#' @keywords hplot
#' @S3method print ggplot
#' @method print ggplot
print.ggplot <- function(x, newpage = is.null(vp), vp = NULL, ...) {
  set_last_plot(x)
  if (newpage) grid.newpage()
  
  data <- ggplot_build(x)
  
  gtable <- ggplot_gtable(data)
  if (is.null(vp)) {
    grid.draw(gtable) 
  } else {
    if (is.character(vp)) seekViewport(vp) else pushViewport(vp)
    grid.draw(gtable) 
    upViewport()
  }
  
  invisible(data)
}

