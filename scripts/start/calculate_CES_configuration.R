# |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
# |  authors, and contributors see CITATION.cff file. This file is part
# |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
# |  AGPL-3.0, you are granted additional permissions described in the
# |  REMIND License Exception, version 1.0 (see LICENSE file).
# |  Contact: remind@pik-potsdam.de
calculate_CES_configuration <- function(cfg, path = getwd(), check = FALSE) {
    CESstring <- paste0("indu_",   cfg$gms$industry,ifelse(cfg$gms$cm_subsec_model_steel=="ces","CesSteel",""),"-",  # remove CesSteel suffix after process-based has been default for some months
                        "buil_",   cfg$gms$buildings,"-",
                        "tran_",   cfg$gms$transport,"-",
                        "GDPpop_", cfg$gms$cm_GDPpopScen, "-",
                        "En_",     cfg$gms$cm_demScen, "-",
                        "Kap_",    cfg$gms$capitalMarket, "-",
                        if (! cfg$gms$cm_calibration_string == "off") paste0(cfg$gms$cm_calibration_string, "-"),
                        "Reg_", madrat::regionscode(file.path(path, cfg$regionmapping))
    )

    ######## Check that CES-file name is not too long ########
    CESfile <- file.path(path, "./modules/29_CES_parameters/load/input", paste0(CESstring, ".inc"))
    if (check && nchar(CESfile) > 255) {
        stop("Filename of CES file has more than 255 characters, which will cause GAMS to fail on loading it.\n",
             "Rename and shorten the path to your REMIND directory by ",
             (nchar(CESfile) - 255), " characters, for instance:\n    ",
             substr(path, 1, nchar(path) - (nchar(CESfile) - 255)), "'")
    }

    ######## Retrieve appropriate gdx file ########
    gdxConfig <- paste0("config/gdx-files/", CESstring, ".gdx")
    
    # Check if the configuration gdx file exists
    if (!file.exists(gdxConfig) && cfg$gms$CES_parameters == "calibrate") {
        cat("Calibration requires a starting gdx that does not exist:\n    ", gdxConfig, "\n")
        abortText <- "Please copy the gdx file with the closest configuration and paste it to that file.\n"
        
        # List available gdx files
        gdxFiles <- list.files("config/gdx-files", pattern = "\\.gdx$", full.names = TRUE)
        if (length(gdxFiles) == 0) { stop(abortText) }
    
        # Prompt user to choose an existing gdx file
        gdxClosest <- gdxFiles[which.min(adist(gdxConfig, gdxFiles))] # existing file with the closest name
        abortOption <- paste0(crayon::red("ABORT"), ": you will then need to copy the gdx of your choice manually")
        gdxFiles <- c(abortOption, gdxFiles)

        gdxSelection <- gdxFiles[gms::chooseFromList(
            ifelse(gdxFiles == gdxClosest, crayon::cyan(gdxFiles), gdxFiles),
            type = "an existing gdx file that you would like to use",
            userinfo = paste0("Leave empty to select existing gdx with ", crayon::cyan("closest name")),
            returnBoolean = TRUE,
            multiple = FALSE
        )]

        if (length(gdxSelection) == 0) { gdxSelection <- gdxClosest } # default option
        if (gdxSelection == abortOption) { stop(abortText) } # abort option
  
        if (file.copy(gdxSelection, gdxConfig)) {
            message("Copied: ", gdxSelection, "\n    to: ", gdxConfig, "\n")
        }
    }

    return(CESstring)
}
