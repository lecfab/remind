#!/usr/bin/env Rscript
# |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  REMIND License Exception, version 1.0 (see LICENSE file).
# |  Contact: remind@pik-potsdam.de

# =============================================================================
# start.R  --  Main entry point for launching REMIND model runs
# =============================================================================
# This script handles configuration and submission of REMIND runs.  It
# supports two mutually exclusive operating modes:
#
#   RESTART/REPREPARE mode  (--restart or --reprepare):
#     Re-submits runs from existing output directories, optionally overriding
#     settings such as --debug, --quick, or --testOneRegi.
#
#   NEW RUN mode  (default):
#     Reads a scenario config CSV (or falls back to built-in defaults),
#     configures each selected run, and either submits it immediately or
#     queues it to wait for a gdx dependency from another scenario.
#
# Both modes support standalone REMIND runs and REMIND-MAgPIE coupled runs.
# Use `Rscript start.R --help` to see all available options.
#
# Script organisation:
#   1. Initialization        -- libraries, help text, sourcing helper functions
#   2. Argument parsing      -- flags, key=value args, config file path
#   3. Early exits & checks  -- --help, --reset, incompatible flag combinations
#   4. Environment setup     -- requirements, renv updates, madrat, output colors
#   5. Global state          -- run counters and small utility functions
#   6. RESTART/REPREPARE branch  -- --restart / --reprepare logic
#   7. NEW RUN branch        -- scenario loop: CSV -> configure -> submit
#   8. Summary & exit        -- final run counts and non-zero exit on errors
# =============================================================================

#### 1. Initialization ####

library(gms)
library(dplyr, warn.conflicts = FALSE)
library(lucode2)
require(stringr, quietly = TRUE)

# Help text displayed by --help (roxygen markers are stripped on output).
helpText <- "
#' Rscript start.R [options] [file]
#'
#' Without [file] argument starts a single REMIND run using the settings from
#' config/default.cfg` and `main.gms`.
#'
#' [file] must be a scenario config .csv file (usually in the config/
#' directory).  Using this will start all REMIND runs specified by
#' \"start = 1\" in that file (check the startgroup option to start a specific
#' group).
#'
#'   --help, -h:         show this help text and exit
#'   --debug, -d:        start a debug run with cm_nash_mode = debug
#'   --gamscompile, -g:  compile gms of all selected runs. Combined with
#'                       --interactive, it stops in case of compilation errors,
#'                       allowing the user to fix them and rerun gamscompile;
#'                       combined with --restart, existing runs can be checked.
#'   --interactive, -i:  interactively select config file and run(s) to be
#'                       started
#'   --quick, -q:        starting one fast REMIND run with one region, one
#'                       iteration and reduced convergence criteria for testing
#'                       the full model.
#'   --reprepare, -R:    rewrite full.gms and restart run
#'   --restart, -r:      interactively restart run(s)
#'   --test, -t:         test scenario configuration without starting the runs
#'   --testOneRegi, -1:  starting the REMIND run(s) in testOneRegi mode
#'   startgroup=MYGROUP  when reading a scenario config .csv file, don't start
#'                       everything specified by \"start = 1\", instead start everything
#'                       specified by \"start = MYGROUP\". Use startgroup=* to start all.
#'   titletag=MYTAG      append \"-MYTAG\" to all titles of all runs that are started
#'   slurmConfig=CONFIG  use the provided CONFIG as slurmConfig: a string, or an integer <= 16
#'                       to select one of the options shown when running './start.R -t'.
#'                       CONFIG is used only for scenarios where no slurmConfig
#'                       is specified in the scenario config csv file, or
#'                       for all scenarios if --debug, --quick or --testOneRegi is used.
#'
#' You can combine --reprepare with --debug, --testOneRegi or --quick and the
#' selected folders will be restarted using these settings.  Afterwards,
#' using --reprepare alone will restart the runs using their original
#' settings.
"

# Load all helper functions from scripts/start/ (configure, submit, slurm utils, ...).
invisible(sapply(list.files("scripts/start", pattern = "\\.R$", full.names = TRUE), source))


#### 2. Argument parsing ####

# Define accepted single-letter shorthands and their long-form equivalents.
acceptedFlags <- c("0" = "--reset", "1" = "--testOneRegi", d = "--debug", g = "--gamscompile", i = "--interactive",
                   r = "--restart", R = "--reprepare", t = "--test", h = "--help", q = "--quick")
# Default startgroup "1": start all scenarios marked start=1 in the CSV.
startgroup <- "1"
# Parse flags and named key=value arguments (startgroup, titletag, slurmConfig).
flags <- lucode2::readArgs("startgroup", "titletag", "slurmConfig", .flags = acceptedFlags, .silent = TRUE)
# If slurmConfig was passed as an integer (1-16), resolve it to the full config string now.
if ("--test" %in% flags) {
  slurmConfig <- choose_slurmConfig(identifier = "1")
 } else if (exists("slurmConfig") && slurmConfig %in% paste(seq(1:16))) {
  slurmConfig <- choose_slurmConfig(identifier = slurmConfig)
}

# Resolve the optional positional argument to a scenario config CSV path.
# Accepted forms: a direct path, a path relative to config/, or just the
# scenario name (expanded to config/scenario_config_<name>.csv).
config.file <- NULL
if(!exists("argv")) argv <- commandArgs(trailingOnly = TRUE)
argv <- argv[! grepl("^-", argv) & ! grepl("=", argv)]
if (length(argv) == 1) {
  config.file <- argv
  if (! file.exists(config.file)) config.file <- file.path("config", argv)
  if (! file.exists(config.file)) config.file <- file.path("config", paste0("scenario_config_", argv, ".csv"))
  if (! file.exists(config.file)) stop("Unknown parameter provided: ", paste(argv, collapse = ", "))
} else if (length(argv) > 1) {
  stop("You provided more than one file or other command line argument, start.R can only handle one: ",
       paste(argv, collapse = ", "))
}

#### 3. Early exits and flag checks ####

# Print help text and quit.
if ("--help" %in% flags) {
  message(gsub("#' ?", '', helpText))
  q()
}

# --reset was removed; notify the user and quit gracefully.
if ("--reset" %in% flags) {
  message("The flag --reset does nothing anymore.")
  q()
}

# --restart cannot be combined with flags that require rewriting full.gms
# (--debug, --quick, --testOneRegi).  The user should use --reprepare instead,
# or confirm interactively to automatically upgrade to --reprepare.
if (any(c("--testOneRegi", "--debug", "--quick") %in% flags) & "--restart" %in% flags & ! "--reprepare" %in% flags) {
  message("\nIt is impossible to combine --restart with --debug, --quick or --testOneRegi because full.gms has to be rewritten.\n",
  "If this is what you want, use --reprepare instead, or answer with y:")
  if (gms::getLine() %in% c("Y", "y")) flags <- c(flags, "--reprepare")
}

#### 4. Environment setup ####

# Check that all required R packages are installed.
ensureRequirementsInstalled()

# Notify the user if the renv lockfile has pending updates.
if (   'TRUE' != Sys.getenv('ignoreRenvUpdates')
    && !getOption("autoRenvUpdates", FALSE)
    && !is.null(piamenv::showUpdates())) {
  message("Consider updating with `piamenv::updateRenv()`.")
  Sys.sleep(1)
}

# Initialise madrat settings (suppresses verbose startup messages).
invisible(madrat::getConfig(verbose = FALSE))

# ANSI escape codes used for colored console output.
red   <- "\033[0;31m"
green <- "\033[0;32m"
blue  <- "\033[0;34m"
NC    <- "\033[0m"   # No Color / reset

#### 5. Global state and utility functions ####

# Run counters incremented throughout the script and reported in the final summary.
errorsfound      <- 0 # non-fatal errors collected during --test or scenario-loop runs
startedRuns      <- 0 # runs submitted or compiled
waitingRuns      <- 0 # runs queued waiting for a gdx dependency
modeltestRunsUsed <- 0 # runs whose input gdx was taken from model tests

# Prints an error message in red and increments errorsfound without stopping
# execution, so that all scenarios can be validated before any run is started.
nonStoppingError <- function(...) {
  message(red, "Error", NC, ": ", ...)
  errorsfound <<- errorsfound + 1
}

# Returns TRUE if 'fullname' ends with 'extension' AND the file exists.
# Example: .isFileAndAvailable("C_SSP2-Base/fulldata.gdx", "fulldata.gdx") => TRUE
.isFileAndAvailable <- function(fullname, extension) {
  isTRUE(stringr::str_sub(fullname, -nchar(extension), -1) == extension) &&
    file.exists(fullname)
}


#### 6 & 7. Main logic: RESTART branch vs. NEW RUN branch ####
# The script now diverges into two mutually exclusive paths:
#
#   RESTART/REPREPARE branch  (the `if` block below):
#     Entered when --restart or --reprepare is given.  Loads config.Rdata
#     from existing output directories, applies any flag overrides
#     (--debug, --quick, --testOneRegi), and re-submits the runs.
#     With --gamscompile, only re-runs the GAMS compiler on existing output.
#
#   NEW RUN branch  (the `else` block, section 7):
#     Default path.  Reads scenario settings from a CSV or uses defaults,
#     configures each selected run, and either submits it immediately or
#     queues it to wait for a gdx dependency from another scenario.

testOneRegi_region <- "" # region for --testOneRegi; empty string means use the default (set in selectTestOneRegiRegion())

# Record the lock state before any runs start, so we can warn later if
# submitted runs will have to queue behind the model lock.
model_was_locked <- if (exists("is_model_locked")) is_model_locked() else file.exists(".lock")

#### 6. RESTART/REPREPARE branch (--restart / --reprepare) ####

if (any(c("--reprepare", "--restart") %in% flags)) {
  # --reprepare needs config.Rdata (to regenerate full.gms); --restart only needs full.gms.
  searchforfile <- if ("--reprepare" %in% flags) "config.Rdata" else "full.gms"
  possibledirs <- basename(dirname(Sys.glob(file.path("output", "*", searchforfile))))
  outputdirs <- gms::chooseFromList(sort(unique(possibledirs)), returnBoolean = FALSE,
                           type = paste0("runs to be re", ifelse("--reprepare" %in% flags, "prepared", "started")))

  # --- 6a. RESTART + --gamscompile: re-compile GAMS code without submitting ---
  if ("--gamscompile" %in% flags) {
    for (outputdir in outputdirs) {
      load(file.path("output", outputdir, "config.Rdata"))
      if (file.exists(file.path("output", outputdir, "main.gms"))) {
        gcresult <- runGamsCompile(file.path("output", outputdir, "main.gms"), cfg, interactive = "--interactive" %in% flags)
        errorsfound <- errorsfound + ! gcresult
        startedRuns <- startedRuns + 1
      } else {
        message(file.path("output", outputdir, "main.gms"), " not found. Skipping this folder.")
      }
    }
  } else {
    # --- 6b. Normal restart/reprepare: apply flag overrides and re-submit ---
    message("\nAlso restart subsequent runs? Enter y, else leave empty:")
    restart_subsequent_runs <- gms::getLine() %in% c("Y", "y")
    if ("--testOneRegi" %in% flags) testOneRegi_region <- selectTestOneRegiRegion()
    # Files to back up (renamed with _beforeRestart suffix) before re-submission.
    # --reprepare additionally backs up full.gms and fulldata.gdx since those will be regenerated.
    filestomove <- c("abort.gdx" = "abort_beforeRestart.gdx",
                     "non_optimal.gdx" = "non_optimal_beforeRestart.gdx",
                     "log.txt" = "log_beforeRestart.txt",
                     "full.lst" = "full_beforeRestart.lst",
                     if ("--reprepare" %in% flags) c("full.gms" = "full_beforeRestart.gms",
                                                     "fulldata.gdx" = "fulldata_beforeRestart.gdx")
                    )
    message("\n", paste(names(filestomove), collapse = ", "), " will be moved and get a postfix '_beforeRestart'.\n")
    if(! exists("slurmConfig")) {
      slurmConfig <- choose_slurmConfig(flags = flags)
    }
    if ("--quick" %in% flags && ! slurmConfig == "direct") slurmConfig <- combine_slurmConfig(slurmConfig, "--time=60")
    message()
    for (outputdir in outputdirs) {
      message("Restarting ", outputdir)
      load(file.path("output", outputdir, "config.Rdata")) # load cfg saved in the existing results folder
      cfg$restart_subsequent_runs <- restart_subsequent_runs
      # Apply flag overrides, saving the original values to cfg$backup so they can
      # be restored the next time --reprepare is run without the override flag.
      if ("--debug" %in% flags) {
        if (is.null(cfg[["backup"]][["cm_nash_mode"]])) cfg$backup$cm_nash_mode <- cfg$gms$cm_nash_mode
        cfg$gms$cm_nash_mode <- 1
      } else {
        if (! is.null(cfg[["backup"]][["cm_nash_mode"]])) cfg$gms$cm_nash_mode <- cfg$backup$cm_nash_mode
      }
      cfg$gms$cm_quick_mode <- if ("--quick" %in% flags) "on" else "off"
      if (any(c("--quick", "--testOneRegi") %in% flags)) {
        if (is.null(cfg[["backup"]][["optimization"]])) cfg$backup$optimization <- cfg$gms$optimization
        cfg$gms$optimization <- "testOneRegi"
        if (testOneRegi_region != "") cfg$gms$c_testOneRegi_region <- testOneRegi_region
      } else {
        if (! is.null(cfg[["backup"]][["optimization"]])) cfg$gms$optimization <- cfg$backup$optimization
      }
      if ("--quick" %in% flags) {
        if (is.null(cfg[["backup"]][["cm_iteration_max"]])) cfg$backup$cm_iteration_max <- cfg$gms$cm_iteration_max
        cfg$gms$cm_iteration_max <- 1
      } else {
        if (! is.null(cfg[["backup"]][["cm_iteration_max"]])) cfg$gms$cm_iteration_max <- cfg$backup$cm_iteration_max
      }
      if (! "--test" %in% flags) {
        filestomove_exists <- file.exists(file.path("output", outputdir, names(filestomove)))
        file.rename(file.path("output", outputdir, names(filestomove[filestomove_exists])),
                    file.path("output", outputdir, filestomove[filestomove_exists]))
      }
      cfg$slurmConfig <- combine_slurmConfig(cfg$slurmConfig, slurmConfig) # apply the slurmConfig chosen above
      cfg$remind_folder <- getwd()         # update remind_folder in case the run was moved to a different repo
      cfg$results_folder <- paste0("output/",outputdir) # update results_folder in case the folder was renamed
      save(cfg,file=paste0("output/",outputdir,"/config.Rdata"))
      startedRuns <- startedRuns + 1
      if (! '--test' %in% flags) {
        submit(cfg, restart = TRUE)
      } else {
        message("   If this wasn't --test mode, I would have restarted ", cfg$title, ".")
      }
    }
  }

} else {

  #### 7. NEW RUN branch ####

  # --- 7a. Interactive config file and region selection ---
  # In interactive mode, let the user pick a scenario config CSV from a list
  # (MAgPIE coupled configs are excluded here; they are selected by passing the
  # _magpie file as a positional argument instead).
  if (is.null(config.file) & "--interactive" %in% flags) {
    possiblecsv <- Sys.glob(c(file.path("./config/scenario_config*.csv"), file.path("./config","*","scenario_config*.csv")))
    possiblecsv <- possiblecsv[! grepl(".*scenario_config_magpie.*csv$", possiblecsv)]
    config.file <- gms::chooseFromList(possiblecsv, type = "one config file", returnBoolean = FALSE, multiple = FALSE)
  }
  if (all(c("--testOneRegi", "--interactive") %in% flags)) testOneRegi_region <- selectTestOneRegiRegion()

  # --- 7b. Load scenario config CSV and select scenarios ---
  # If a scenario_config CSV was provided, read and validate it.  A filename
  # containing "_magpie" signals REMIND-MAgPIE coupled mode: the file is the
  # MAgPIE-side config; the matching REMIND config is derived by removing
  # "_magpie" from the filename.
  if (! length(config.file) == 0) {

    # Detect coupled mode from the config filename.
    if (grepl("_magpie", config.file)) {
      message("\nStarting REMIND in coupled mode with MAgPIE,\n as you have provided a scenario_config_magpie.csv.\nReading ", config.file)
      settings_magpie <- readCheckScenarioConfig(config.file, ".")
      scenarios_magpie <- selectScenarios(settings = settings_magpie, interactive = "--interactive" %in% flags, startgroup = startgroup)
      config.coupled <- config.file
      config.file <- gsub("_magpie", "", config.file)
    }

    message("Reading config file ", config.file)

    # Read and validate the REMIND scenario config table (rows = scenarios, columns = switches).
    settings <- readCheckScenarioConfig(config.file, ".")

    if(!exists("scenarios_magpie")) {
      # Standalone REMIND: select scenarios to run from the config table.
      scenarios <- selectScenarios(settings = settings, interactive = "--interactive" %in% flags, startgroup = startgroup)
    } else {
      # --- Coupled mode: reconcile MAgPIE and REMIND scenario lists ---
      # Only run scenarios present in both configs.  Scenarios missing from
      # one side are reported but do not cause an abort.
      missing <- setdiff(rownames(scenarios_magpie),rownames(settings))
      if (!identical(missing, character(0))) {
        message("The following scenarios are given in '",config.coupled ,"' but could not be found in '", config.file, "':")
        message("  ", paste(missing, collapse = ", "), "\n")
      }
      common <- intersect(rownames(settings), rownames(scenarios_magpie))
      if (! identical(common, character(0))) {
        message("\n################################\n")
        message("The following ", length(common), " scenarios will be started:")
        message("  ", paste(common, collapse = ", "))
      } else {
        stop("No scenario found with start=", startgroup, " in ", config.coupled, " that is also defined in ", config.file, ".")
      }
      scenarios <- settings[common,]
      
      # Locate the MAgPIE repository (expected as a sibling of the REMIND directory).
      path_magpie <- normalizePath(file.path(getwd(), "magpie"), mustWork = FALSE)
      if (! dir.exists(path_magpie)) path_magpie <- normalizePath(file.path(getwd(), "..", "magpie"), mustWork = FALSE)
      
    }    
    
  } else {
    # No CSV provided: create a one-row dummy scenarios table so the loop below
    # runs exactly once with either the default or testOneRegi configuration.
    if (any(c("--quick", "--testOneRegi") %in% flags)) {
      scenarios <- data.frame("testOneRegi" = "testOneRegi", row.names = "testOneRegi")
    } else {
      scenarios <- data.frame("default" = "default", row.names = "default")
    }
  }

  # Append the titletag suffix to all scenario titles (if --titletag was provided).
  if (exists("titletag")) {
    scenarios <- addTitletag(titletag = titletag, scenarios = scenarios)
  }

  # --- 7c. Determine the SLURM submission configuration ---
  # With --gamscompile the submission mode is always "direct" (no SLURM job needed).
  # Otherwise, ask the user to choose a slurmConfig if it is not already known
  # (i.e. not provided on the command line and not set for every scenario in the CSV).
  if ("--gamscompile" %in% flags) {
    slurmConfig <- "direct"
    message("\nTrying to compile ", nrow(scenarios), " selected runs...")
    lockID <- gms::model_lock()
    if (length(missingInputData()) > 0) {
      # Ensure input data is available before compiling (checked once, not per scenario).
      updateInputData(readDefaultConfig("."), remindPath = ".", gamsCompile = FALSE)
    }
  }
  if (! exists("slurmConfig") & (any(c("--debug", "--quick", "--testOneRegi") %in% flags)
      | ! "slurmConfig" %in% names(scenarios) || any(is.na(scenarios$slurmConfig)))) {
    slurmConfig <- choose_slurmConfig(flags = flags)
    if ("--quick" %in% flags && ! slurmConfig == "direct") slurmConfig <- combine_slurmConfig(slurmConfig, "--time=60")
    if (any(c("--debug", "--quick", "--testOneRegi") %in% flags) && ! length(config.file) == 0) {
      message("\nYour slurmConfig selection will overwrite the settings in your scenario_config file.")
    }
  }

  # --- 7d. Main scenario loop ---
  # Iterate over every selected scenario: re-read defaults, apply CSV and
  # command-line overrides, configure MAgPIE (if coupled), validate the final
  # cfg, then either submit the run, queue it, or compile it.
  for (scen in rownames(scenarios)) {

    # Re-read default config for each scenario to get a clean starting state
    # and avoid carrying over state (e.g. gdx entries in files2export) between scenarios.
    cfg <- readDefaultConfig(".")

    # Write the GAMS log to file rather than to the console.
    cfg$logoption   <- 2
    # start_now is set to FALSE below if this run must wait for a gdx from another scenario.
    start_now       <- TRUE

    # --- 7d-i. Apply --testOneRegi / --quick overrides (no-CSV case only) ---
    # When no CSV is given, cfg is built entirely from defaults and these flags.
    if (any(c("--quick", "--testOneRegi") %in% flags) & length(config.file) == 0) {
      cfg$title            <- scen
      cfg$description      <- "A REMIND run with default settings using testOneRegi"
      cfg$gms$optimization <- "testOneRegi"
      cfg$output           <- NA
      cfg$results_folder   <- paste0("output/", cfg$title)
      cfg$force_replace    <- TRUE # delete existing Results directory
      if (testOneRegi_region != "") cfg$gms$c_testOneRegi_region <- testOneRegi_region
    }
    if ("--quick" %in% flags) {
        cfg$gms$cm_quick_mode <- "on"
        cfg$gms$cm_iteration_max <- 1
    }
    if (! "--gamscompile" %in% flags || "--interactive" %in% flags) {
      message("\n", if (length(config.file) == 0) cfg$title else scen)
    }

    # --- 7d-ii. Configure cfg from the CSV scenario table ---
    if (! length(config.file) == 0) {
      if (exists("scenarios_magpie")) cfg$gms$cm_MAgPIE_Nash <- 1 # signal coupled mode to configureCfg
      cfg <- configureCfg(cfg, scen, scenarios,
                          verboseGamsCompile = ! "--gamscompile" %in% flags || "--interactive" %in% flags)
      errorsfound <- sum(errorsfound, cfg$errorsfoundInConfigureCfg)
      cfg$errorsfoundInConfigureCfg <- NULL

      # --testOneRegi / --quick override any optimization settings from the CSV.
      if (any(c("--quick", "--testOneRegi") %in% flags)) {
        cfg$description      <- paste("testOneRegi:", cfg$description)
        cfg$gms$optimization <- "testOneRegi"
        cfg$output           <- NA
        cfg$slurmConfig      <- slurmConfig # command-line slurmConfig takes precedence over CSV value
        if (testOneRegi_region != "") cfg$gms$c_testOneRegi_region <- testOneRegi_region
      }
      # A run can start immediately only if all required gdx inputs are already
      # available as explicit file paths (not as references to other scenarios).
      gdx_specified <- grepl(".gdx", cfg$files2export$start[path_gdx_list], fixed = TRUE)
      gdx_na <- is.na(cfg$files2export$start[path_gdx_list])
      start_now <- all(gdx_specified | gdx_na)
      if (start_now && (! "--gamscompile" %in% flags || "--interactive" %in% flags)) {
        message("   Run can be started using ", sum(gdx_specified), " specified gdx file(s).")
        if (sum(gdx_specified) > 0) message("     ", paste0(path_gdx_list[gdx_specified], ": ", cfg$files2export$start[path_gdx_list][gdx_specified], collapse = "\n     "))
      }
    }

    # --debug forces Nash debug mode and the user-chosen slurmConfig.
    if ("--debug" %in% flags) {
      cfg$gms$cm_nash_mode <- 1
      cfg$slurmConfig      <- slurmConfig
    }

    # Last-resort slurmConfig fallback: ask the user if it is still unset.
    if (cfg$slurmConfig %in% c(NA, "")) {
      if(! exists("slurmConfig")) slurmConfig <- choose_slurmConfig(flags = flags)
      cfg$slurmConfig <- slurmConfig
    }

    # abort on too long paths ----
    cfg$gms$cm_CES_configuration <- calculate_CES_configuration(cfg, check = TRUE)

    # offer to copy existing gdx when missing required calibration gdx (interactive mode only) ----
    if ("--interactive" %in% flags && cfg$gms$CES_parameters == "calibrate") {
      gdxFolder <- "./config/gdx-files"
      gdxConfig <- file.path(gdxFolder, paste0(cfg$gms$cm_CES_configuration, ".gdx"))
      if (!file.exists(gdxConfig)) {
        message("\nCalibration requires a starting gdx that does not exist:\n    ", gdxConfig)
        abortText <- paste0("Please copy the gdx file with the closest configuration and paste it to:\n    ", gdxConfig, "\n")

        # List available gdx files
        gdxFiles <- list.files(gdxFolder, pattern = "\\.gdx$", full.names = TRUE)
        if (length(gdxFiles) > 0) { # length is zero when input data has not been collected yet and copying gdx is impossible
          # Prompt user to choose an existing gdx file
          gdxClosest <- gdxFiles[which.min(adist(basename(gdxConfig), basename(gdxFiles)))] # existing file with the closest name
          abortOption <- paste0(crayon::red("ABORT"), ": you will then need to copy the gdx of your choice manually")
          gdxFiles <- c(abortOption, gdxFiles)
          gdxSelection <- gdxFiles[gms::chooseFromList(
            ifelse(gdxFiles == gdxClosest, crayon::cyan(gdxFiles), gdxFiles),
            type = "an existing gdx file that you would like to use",
            userinfo = paste0("Leave empty to select existing gdx with ", crayon::cyan("most similar name")),
            returnBoolean = TRUE,
            multiple = FALSE
          )]

          if (length(gdxSelection) == 0) { gdxSelection <- gdxClosest } # default option
          if (gdxSelection == abortOption || !file.copy(gdxSelection, gdxConfig)) { # abort option or copy failure
            nonStoppingError(abortText)
          } else {
            message("Copied: ", gdxSelection, "\n    to: ", gdxConfig, "\n")

            # Add the .gdx and .inc to list of possible names
            addLine <- function(line, path = "files") {
              if (!file.exists(path)) message(path, " does not exist, you may have to manually add ", line)
              else if (!(line %in% readLines(path))) {
                write(line, path, append = TRUE)
                message("Added in ", path, " the line ", line)
              }
            }
            addLine(paste0(cfg$gms$cm_CES_configuration, ".gdx"), path = file.path(gdxFolder, "files"))
            addLine(paste0(cfg$gms$cm_CES_configuration, ".inc"), path = file.path("./modules/29_CES_parameters/load/input", "files"))
          }
        }
      }
    }

    # --- 7d-iii. Configure REMIND-MAgPIE coupling (coupled mode only) ---
    # This block is entered only when a scenario_config_magpie CSV was provided
    # (i.e. when the scenarios_magpie object exists).  It builds cfg_mag (the
    # MAgPIE configuration object) and attaches it to cfg so that submit() can
    # start both models in a coordinated way.
    if (exists("scenarios_magpie")) {
    
      # Apply scenario-specific Nash iteration count override if given.
      if ("magpieIter" %in% names(scenarios_magpie) && !is.na(scenarios_magpie[scen, "magpieIter"])) {
        cfg$gms$c_magpieIter <- scenarios_magpie[scen, "magpieIter"]
      }        
      
      # Handle continueFromHere: resume a partially completed coupled run.
      # The action taken depends on the file type given in continueFromHere:
      #   report.mif   -> MAgPIE already ran; only getMagpieData() is needed before REMIND
      #   *.mif        -> REMIND report exists; run MAgPIE without producing a new REMIND report
      #   fulldata.gdx -> REMIND gdx exists; run the full magpie.R coupling script
      if ("continueFromHere" %in% names(scenarios_magpie) && !is.na(scenarios_magpie[scen, "continueFromHere"])) {
        # Prepend iteration 1 so magpie.R is triggered in the very first Nash iteration.
        cfg$gms$c_magpieIter <- paste0("1,", cfg$gms$c_magpieIter) 

        if (.isFileAndAvailable(scenarios_magpie[scen, "continueFromHere"], "report.mif")) {
          # MAgPIE report -> continue with REMIND: only run getMagpieData(), skip MAgPIE.
          cfg$continueFromHere <- c("getMagpieData" = scenarios_magpie[scen, "continueFromHere"])
          message("   Continuing MAgPIE coupling from MAgPIE report ", scenarios_magpie[scen, "continueFromHere"])
        } else if (.isFileAndAvailable(scenarios_magpie[scen, "continueFromHere"], ".mif")) {
          # REMIND generic report (*.mif, not report.mif) -> run MAgPIE without a new REMIND report.
          cfg$continueFromHere <- c("runMAgPIE" = scenarios_magpie[scen, "continueFromHere"])
          # Use the fulldata.gdx from the same folder as the start gdx.
          cfg$files2export$start["input.gdx"] <- file.path(dirname(scenarios_magpie[scen, "continueFromHere"]), "fulldata.gdx")
          message("   Continuing MAgPIE coupling from REMIND report ", scenarios_magpie[scen, "continueFromHere"])
        } else if (.isFileAndAvailable(scenarios_magpie[scen, "continueFromHere"], "fulldata.gdx")) {
          # REMIND fulldata.gdx -> run the full magpie.R (MAgPIE + produce a REMIND report).
          cfg$continueFromHere <- c("full" = scenarios_magpie[scen, "continueFromHere"])
          # Use the REMIND gdx directly as the start gdx.
          cfg$files2export$start["input.gdx"] <- scenarios_magpie[scen, "continueFromHere"]
          message("   Continuing MAgPIE coupling from REMIND gdx ", scenarios_magpie[scen, "continueFromHere"])
        } else {
          nonStoppingError("Could not find what is given in 'scenarios_magpie[scen, continueFromHere]': ", scenarios_magpie[scen, "continueFromHere"])
        }
      }
      
      cfg$title <- paste0("C_", cfg$title)                                         # "C_" prefix marks coupled runs
      cfg$output <- c(setdiff(cfg$output, "plotRemMagNash"), "plotRemMagNash")     # ensure convergence plot is included
      cfg$path_magpie <- path_magpie
      cfg$magpie_empty <- isTRUE(scenarios_magpie[scen, "magpie_empty"])           # TRUE replaces MAgPIE with a no-op stub
      cfg$slurmConfig <- combine_slurmConfig(cfg$slurmConfig, "--comment=REMIND-MAgPIE")
      
      # Load MAgPIE default config into an isolated environment, then configure it.
      magpieEnv <- new.env()
      source(file.path(path_magpie, "config", "default.cfg"), local = magpieEnv)
      cfg_mag <- magpieEnv$cfg

      cfg_mag$sequential <- TRUE
      cfg_mag$force_replace <- TRUE

      # Apply MAgPIE scenario presets listed in the coupled config.
      # Columns named 'magpie_scen' use MAgPIE's own config/scenario_config.csv;
      # columns whose name is a path use that scenario_config file instead.
      magpieScenarios <- scenarios_magpie[scen, grepl("scenario_config|magpie_scen", colnames(scenarios_magpie)), drop = FALSE]

      # Configure MAgPIE using the scenario presets extracted above.
      message("Configuring MAgPIE")
      if (nrow(magpieScenarios) > 0) {
        for (i in seq_len(ncol(magpieScenarios))) {
          pathToScenarioConfig <- colnames(magpieScenarios)[i]
          # Backwards compatibility: bare 'magpie_scen' column maps to MAgPIE's default scenario config.
          pathToScenarioConfig <- ifelse(pathToScenarioConfig == "magpie_scen", "config/scenario_config.csv", pathToScenarioConfig)
          scenarioList <- magpieScenarios[,i]
          if(!is.na(scenarioList)) {
            cfg_mag <- setScenario(cfg_mag, trimws(unlist(strsplit(scenarioList, split = ",|\\|"))),
                                   scenario_config = file.path(path_magpie, pathToScenarioConfig))
          }
        }
      }

      # Always activate the 'coupling' scenario so MAgPIE uses coupled-mode settings.
      cfg_mag <- gms::setScenario(cfg_mag, "coupling", scenario_config = file.path(path_magpie, "config", "scenario_config.csv"))

      # Apply individual MAgPIE switches given directly in the coupled config
      # (columns starting with "cfg_mag$").  NAs are replaced with "" to avoid
      # errors in setScenario.
      magpieSwitches <- scenarios_magpie %>% select(contains("cfg_mag")) %>% t() %>% as.data.frame() %>% replace(is.na(.), "")

      # Configure MAgPIE according to individual switches from scenario_config_magpie*.csv.
      if (nrow(magpieSwitches) > 0) {
        # Strip the "cfg_mag$" prefix to yield the original MAgPIE switch names.
        row.names(magpieSwitches) <- gsub("cfg_mag\\$", "", row.names(magpieSwitches))
        cfg_mag <- setScenario(cfg_mag, scen, scenario_config = magpieSwitches)
      }

      cfg_mag <- check_config(cfg_mag, reference_file = file.path(path_magpie, "config", "default.cfg"),
                              modulepath = file.path(path_magpie, "modules"))

      # Mute GHG prices in MAgPIE up to and including the specified year.
      cfg_mag$gms$c56_mute_ghgprices_until <- scenarios_magpie[scen, "no_ghgprices_land_until"]

      # Optionally use GHG prices from a different REMIND run for the land sector.
      # The value must be a path to an existing .mif file; referencing another
      # scenario by name is not yet supported (see TODO comment below).
      path_mif_ghgprice_land <- NULL
      if ("path_mif_ghgprice_land" %in% names(scenarios_magpie)) {
        if (! is.na(scenarios_magpie[scen, "path_mif_ghgprice_land"])) {
          if (.isFileAndAvailable(scenarios_magpie[scen, "path_mif_ghgprice_land"], ".mif")) {
              # Direct file path provided: use it as-is.
              path_mif_ghgprice_land <- normalizePath(scenarios_magpie[scen, "path_mif_ghgprice_land"])
          } else if (scenarios_magpie[scen, "path_mif_ghgprice_land"] %in% common) {
              # TODO: referencing another scenario by name as GHG price source requires
              # implementing run-ordering so the referenced run is guaranteed to finish first.
              # The commented-out lines below show the intended approach once that is in place.
              #ghgprice_remindrun <- paste0(prefix_runname, scenarios_magpie[scen, "path_mif_ghgprice_land"], "-rem-", i)
              #path_mif_ghgprice_land <- file.path(path_remind, "output", ghgprice_remindrun, paste0("REMIND_generic_", ghgprice_remindrun, ".mif"))
              nonStoppingError("path_mif_ghgprice_land must be a path to an existing file and cannot reference another scenario by name currently: ",
                      scenarios_magpie[scen, "path_mif_ghgprice_land"])
              path_mif_ghgprice_land <- FALSE
          } else {
            nonStoppingError("path_mif_ghgprice_land is neither an existing file nor a scenario that will be started: ",
                    scenarios_magpie[scen, "path_mif_ghgprice_land"])
            path_mif_ghgprice_land <- FALSE
          }
          cfg_mag$path_to_report_ghgprices <- path_mif_ghgprice_land
        }
      }

      # TODO: The block below (currently commented out) would set numberOfTasks
      # dynamically so that nash mode uses one CPU per region plus one, while
      # negishi and model tests use a single CPU.  Uncomment once the necessary
      # infrastructure for passing numberOfTasks to the SLURM submission is in place.
      #if (cfg_rem$gms$optimization == "nash" && cfg_rem$gms$cm_nash_mode == 2 && isFALSE(magpie_empty)) {
      #  numberOfTasks <- length(unique(read.csv2(cfg_rem$regionmapping)$RegionCode)) + 1
      #} else {
      #  numberOfTasks <- 1
      #}
  
      errorsfound <- errorsfound + checkSettingsRemMag(cfg, cfg_mag, testmode = "--test" %in% flags)
      
      cfg <- append(cfg, list("cfg_mag" = cfg_mag))
    }

    # --- end of coupled MAgPIE configuration ---

    # --- 7d-iv. Final config validation ---
    # checkFixCfg validates the assembled cfg, applies automatic fixes where
    # possible, and counts any additional errors that should block submission.
    cfg <- checkFixCfg(cfg, testmode = "--test" %in% flags)
    if ("errorsfoundInCheckFixCfg" %in% names(cfg)) {
      errorsfound <- errorsfound + cfg$errorsfoundInCheckFixCfg
    }

    # --- 7d-v. Save cfg and submit (or queue) the run ---
    # Write cfg to an RData file so that subsequent chained runs can be
    # started automatically by the cluster job of the preceding run.
    if (! any(c("--test", "--gamscompile") %in% flags)) {
      filename <- paste0(cfg$title,".RData")
      message("   Writing cfg to file ", filename)
      save(cfg, file=filename)
    }
    startedRuns <- startedRuns + start_now
    waitingRuns <- waitingRuns + 1 - start_now
    if ("--test" %in% flags && start_now) {
      message("   If this wasn't --test mode, I would submit ", scen, ".")
    } else if ("--gamscompile" %in% flags) {
      gcresult <- runGamsCompile(if (is.null(cfg$model)) "main.gms" else cfg$model, cfg, interactive = "--interactive" %in% flags)
      errorsfound <- errorsfound + ! gcresult
    } else if (start_now) {
      if (errorsfound == 0) {
        # set up local calibration folder if not yet present ----
        caldir <- "calibration_results/"
        if (cfg$gms$CES_parameters == "calibrate" && !dir.exists(caldir)) {
          if (0 == system("./scripts/utils/set-local-calibration.sh")) {
            message("   Folder ", caldir, " has been automatically set up.")
            cfg$repositories <- append(cfg$repositories, setNames(list(NULL), normalizePath(caldir)))
            source(file.path(caldir, ".Rprofile_calibration_results"))
          } else {
            warning("   Could not set up ", caldir, " automatically. Please run 'make set-local-calibration' manually.")
          }
        }
        submit(cfg)
      } else {
        message("   Not started, as errors were found.")
      }
    }
    # Report dependency and chaining information for this scenario.
    if (! "--gamscompile" %in% flags || "--interactive" %in% flags) {
      if (! start_now) {
        message("   Waiting for: ", paste(unique(cfg$files2export$start[path_gdx_list][! gdx_specified & ! gdx_na]), collapse = ", "))
      }
      if (length(rownames(cfg$RunsUsingTHISgdxAsInput)) > 0) {
        message("   Subsequent runs: ", paste(rownames(cfg$RunsUsingTHISgdxAsInput), collapse = ", "))
      }
    }
  } # end of scenario loop
  message("")
  if (exists("lockID")) gms::model_unlock(lockID)
}

#### 8. Summary and exit ####

warnings()

# Print a final summary line with run counts.
message("\nFinished: ", startedRuns, " runs started. ", waitingRuns, " runs are waiting. ",
        if (modeltestRunsUsed > 0) paste0(modeltestRunsUsed, " GDX files from modeltests selected."))
# Print mode-specific advice or warnings.
if ("--gamscompile" %in% flags) {
  message("To investigate potential FAILs, run: less -j 4 --pattern='^\\*\\*\\*\\*' filename.lst")
} else if ("--test" %in% flags) {
  message("You are in --test mode: no runs were started. ", errorsfound, " errors were identified.")
} else if (model_was_locked & (! "--restart" %in% flags | "--reprepare" %in% flags)) {
  message("The model was locked before runs were started, so they will have to queue.")
}

# Return a non-zero exit status when errors were collected, so that calling
# scripts or CI pipelines can detect failure.
if (0 < errorsfound) {
  stop(errorsfound, " errors were identified, check logs above for details.")
}
