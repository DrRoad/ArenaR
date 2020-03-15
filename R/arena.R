#' Creates arena object
#'
#' @param live Defines if arena should start live server or generate static json
#' @return Empty \code{arena_static} of \code{arena_live} class object
#' @examples
#' library(dplyr)
#' explainer <- DALEX::explain(model, data = df, y = df$y)
#' arena <- new_arena(live = TRUE) %>%
#'   arena_push_model(explainer) %>%
#'   arena_push_observations(df[1:10, ])
#'   arena_run()
#' @export
new_arena <- function(live = FALSE) {
  if (live) return(
    structure(
      list(
        explainers = list(),
        # batch = one data frame of observations
        observations_batches = list(),
        timestamp = as.numeric(Sys.time())
      ),
      class = "arena_live"
    )
  )
  else return(
    structure(
      list(
        explainers = list(),
        # batch = one data frame of observations
        observations_batches = list(),
        plots_data = list()
      ),
      class = "arena_static"
    )
  )
}

#' Prints static arena summary
#'
#' @param arena \code{arena_static} object
#' @export
print.arena_static <- function(arena) {
  cat("===== Static Arena Summary =====\n")
  jstr <- get_json_structure(arena)
  cat(paste("Models:", paste(jstr$models, collapse = ", "), "\n"))
  cat(paste("Observations:", paste(jstr$observations, collapse = ", "), "\n"))
  cat(paste("Variables:", paste(jstr$variables, collapse = ", "), "\n"))
  cat(paste("Plots count:", length(jstr$data), "\n"))
}

#' Prints live arena summary
#'
#' @param arena \code{arena_live} object
print.arena_live <- function(arena) {
  cat("===== Live Arena Summary =====\n")
  jstr <- get_json_structure(arena)
  cat(paste("Models:", paste(jstr$models, collapse = ", "), "\n"))
  cat(paste("Observations:", paste(jstr$observations, collapse = ", "), "\n"))
  cat(paste("Variables:", paste(jstr$variables, collapse = ", "), "\n"))
  cat("Remember to start server with arena_run(arena)\n")
}

#' Adds model to arena
#'
#' If arena is static it will start calculations for all already pushed
#' observations and global plots. If arena is live, then plots will be
#' calculated on demand, after calling \code{arena_run}.
#' 
#' @param arena live or static arena object
#' @param explainer Explainer created usign \code{DALEX::explain}
#' @return Updated arena object
#' @export
arena_push_model <- function(arena, explainer) {
  UseMethod("arena_push_model")
}

#' @export
arena_push_model.arena_static <- function(arena, explainer) {
  if (is.null(arena) || !is(arena, "arena_static")) {
    stop("Invalid arena argument")
  }
  validate_new_model(arena, explainer)
  
  # calculate global plots and append to list
  arena$plots_data <- c(arena$plots_data, get_global_plots(explainer))
  # for each observations data frame calculate local plots
  local_plots <- lapply(
    arena$observations_batches,
    function(observations) get_local_plots(explainer, observations)
  )
  # flatten result and add to plots
  arena$plots_data <- c(
    arena$plots_data,
    unlist(local_plots, recursive = FALSE)
  )
  # save this explainer
  arena$explainers[[length(arena$explainers) + 1]] <- explainer
  arena
}

#' @export
arena_push_model.arena_live <- function(arena, explainer) {
  if (is.null(arena) || !is(arena, "arena_live")) {
    stop("Invalid arena argument")
  }
  validate_new_model(arena, explainer)
  
  # save explainer
  arena$explainers[[length(arena$explainers) + 1]] <- explainer
  # update timestamp
  arena$timestamp <- as.numeric(Sys.time())
  arena
}

#' Adds new observations to arena
#' 
#' If arena is static it will start calculations for all already pushed
#' models. If arena is live, then plots will be calculated on demand,
#' after calling \code{arena_run}.
#'
#' @param arena live or static areana object
#' @param observations dataframe of new observations
#' @return Updated arena object
#' @export
arena_push_observations <- function(arena, observations) {
  UseMethod("arena_push_observations")
}

#' @export
arena_push_observations.arena_static <- function(arena, observations) {
  if (is.null(arena) || !is(arena, "arena_static")) {
    stop("Invalid arena argument")
  }
  validate_new_observations(arena, observations)

  # helper function get local plots for fixed observations
  get_local <- function(expl) get_local_plots(expl, observations)

  arena$plots_data <- c(
    arena$plots_data,
    # for each explainer calculate local plots and flatten results into one list
    unlist(lapply(arena$explainers, get_local), recursive = FALSE)
  )
  # save observations batch
  n <- length(arena$observations_batches) + 1
  arena$observations_batches[[n]] <- observations
  arena
}

#' @export
arena_push_observations.arena_live <- function(arena, observations) {
  if (is.null(arena) || !is(arena, "arena_live")) {
    stop("Invalid arena argument")
  }
  validate_new_observations(arena, observations)

  # save observations
  n <- length(arena$observations_batches) + 1
  arena$observations_batches[[n]] <- observations
  # update timestamp
  arena$timestamp <- as.numeric(Sys.time())
  arena
}

#' Upload generated json file from static arena
#'
#' By default function opens browser with new arena session. Appending data to
#' already existing session is also possible usign argument \code{append_data}
#'
#' @param arena Static arena object
#' @param open_browser Whether to open browser with new session
#' @param append_data Whether to append data to already existing session
#' @return not modified arena object
#' @export
arena_upload <- function (arena, open_browser = TRUE, append_data = FALSE) {
  if (is.null(arena) || !is(arena, "arena_static")) {
    stop("Invalid arena argument")
  }
  # generate json string
  json <- jsonlite::toJSON(
    get_json_structure(arena),
    auto_unbox=TRUE,
    pretty=TRUE
  )
  # upload json to gist
  gist <- gistr::gist_create(
    public=FALSE,
    browse=FALSE,
    code=json,
    filename="data.json"
  )
  # url of raw data file
  url <- gist$files$data.json$raw_url
  print(paste("Data url: ", url))
  if (append_data) {
    # append data to already existing session
    browseURL(paste0("https://piotrpiatyszek.github.io/arena/?append=", url))
  } else if (open_browser) {
    # open new session
    browseURL(paste0("https://piotrpiatyszek.github.io/arena/?data=", url))
  }
  arena
}