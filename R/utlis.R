#' Checks if it is safe do add new observations to the arena object
#'
#' Function checks if rowname of each row is not already used
#'
#' @param arena live or static arena object
#' @param observations data frame of new observations
#' @importFrom methods is
validate_new_observations <- function(arena, observations) {
  if (is.null(observations) || !is(observations, "data.frame")) {
    stop("Invalid observations argument")
  }
  if (length(intersect(get_observations_list(arena), rownames(observations)))) {
    stop("Observations rownames must be unique")
  }
}

#' Checks if it is safe do add a new model to the arena object
#'
#' Function checks if label is not already used
#' @param arena live or static arena object
#' @param explainer Explainer created using \code{DALEX::explain}
#' @importFrom methods is
validate_new_model <- function(arena, explainer) {
  if (is.null(explainer) || !is(explainer, "explainer")) {
    stop("Invalid explainer argument")
  }
  labels <- sapply(arena$explainers, function(x) x$label)
  if (explainer$label %in% labels) {
    stop("Explainers must have unique label")
  }
}

#' Generates list of rownames of each observation from each batch
#'
#' @param arena live or static arena object
get_observations_list <- function(arena) {
  as.list(unlist(lapply(arena$observations_batches, rownames)))
}

#' Generates list of unique variables(without y) from each explainer
#'
#' @param arena live or static arena object
get_variables_list <- function(arena) {
  as.list(unique(unlist(lapply(arena$explainers, function(expl) {
    is_y <- sapply(expl$data, function(column) { identical(column, expl$y) })
    names(is_y[!is_y])
  }))))
}

#' Prepare object ready to change into json
#'
#' @param arena live or static arena object
#' @importFrom methods is
get_json_structure <- function(arena) {
  UseMethod("get_json_structure")
}

#' @importFrom methods is
get_json_structure.arena_static <- function(arena) {
  if (is.null(arena) || !is(arena, "arena_static")) {
    stop("Invalid arena argument")
  }
  list(
    version = "1.0.0",
    observations = get_observations_list(arena),
    variables = get_variables_list(arena),
    models = lapply(arena$explainers, function(x) x$label),
    data = arena$plots_data
  )
}

#' @importFrom methods is
get_json_structure.arena_live <- function(arena) {
  if (is.null(arena) || !is(arena, "arena_live")) {
    stop("Invalid arena argument")
  }
  list(
    version = "1.0.0",
    api = "arenar_api",
    timestamp = arena$timestamp*1000,
    observations = get_observations_list(arena),
    variables = get_variables_list(arena),
    models = lapply(arena$explainers, function(x) { x$label }),
    availablePlots = list(
      list(
        name = "Break Down",
        plotType = "Breakdown",
        plotCategory = "Observation Level",
        requiredParams = list("model", "observation")
      ),
      list(
        name = "Ceteris Paribus",
        plotType = "CeterisParibus",
        plotCategory = "Observation Level",
        requiredParams = list("model", "observation", "variable")
      ),
      list(
        name = "Shapley Values",
        plotType = "SHAPValues",
        plotCategory = "Observation Level",
        requiredParams = list("model", "observation")
      ),
      list(
        name = "Partial Dependence",
        plotType = "PartialDependence",
      plotCategory = "Dataset Level",
        requiredParams = list("model", "variable")
      ),
      list(
        name = "Accumulated Dependence",
        plotType = "AccumulatedDependence",
      plotCategory = "Dataset Level",
        requiredParams = list("model", "variable")
      ),
      list(
        name = "Variable Importance",
        plotType = "FeatureImportance",
      plotCategory = "Dataset Level",
        requiredParams = list("model")
      )
    )
  )
}
