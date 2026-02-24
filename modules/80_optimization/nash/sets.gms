*** |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/80_optimization/nash/sets.gms

***-----------------------------------------------------------------------------
***  Learning technologies included in Nash mode
***  (these determine inter-regional spillover externalities)
***-----------------------------------------------------------------------------
sets
  learnte_dyn80(all_te)   "learning technologies considered in Nash mode"
  /
    spv         "solar photovoltaic"
    csp         "concentrating solar power"
    windon      "wind onshore power converters"
    windoff     "wind offshore power converters"
    storspv     "storage technology for spv"
    storcsp     "storage technology for csp"
    storwindon  "storage technology for wind onshore"
    storwindoff "storage technology for wind offshore"
  /,

***-----------------------------------------------------------------------------
***  Solver statistics tracked per region and iteration
***-----------------------------------------------------------------------------
  solveinfo80   "Nash solver statistics"
  /
    solvestat, modelstat, resusd, objval
  /,

***-----------------------------------------------------------------------------
***  Convergence criteria: all possible criteria plus the active subset
***-----------------------------------------------------------------------------
  convMessage80   "all possible Nash convergence criteria"
  /
    infes, surplus, nonopt, taxconv, anticip,
    globalbudget, peakbudgyr, peakbudget, regiBudget,
    regiTarget, NDC, implicitEnergyTarget,
    cm_implicitPriceTarget, cm_implicitPePriceTarget,
    damage, DevPriceAnticip, IterationNumber
  /,

  activeConvMessage80(convMessage80)   "currently active convergence criteria" / /
;

*** Mark learning technologies as active
teLearn(learnte_dyn80) = YES;

***-----------------------------------------------------------------------------
***  Activate convergence criteria
***  Criteria are checked every iteration; all active criteria must be met
***  before Nash is declared converged.
***-----------------------------------------------------------------------------
activeConvMessage80("infes")         = YES;
activeConvMessage80("surplus")       = YES;
activeConvMessage80("nonopt")        = YES;
activeConvMessage80("IterationNumber") = YES;

*** Tax revenue convergence (optional, controlled by cm_TaxConvCheck)
if (cm_TaxConvCheck eq 1, activeConvMessage80("taxconv") = YES;);

activeConvMessage80("globalbudget")  = YES;

*** Peak-budget year criteria only apply under functionalForm carbon pricing
$if %carbonprice% == "functionalForm" activeConvMessage80("peakbudgyr") = YES;
$if %carbonprice% == "functionalForm" activeConvMessage80("peakbudget") = YES;

activeConvMessage80("DevPriceAnticip") = YES;

*** Conditional criteria based on active policy modules
$if not "%cm_emiMktTarget%"        == "off" activeConvMessage80("regiTarget")              = YES;
$if not "%cm_implicitQttyTarget%"  == "off" activeConvMessage80("implicitEnergyTarget")    = YES;
$if not "%cm_implicitPriceTarget%" == "off" activeConvMessage80("cm_implicitPriceTarget")  = YES;
$if not "%cm_implicitPePriceTarget%" == "off" activeConvMessage80("cm_implicitPePriceTarget") = YES;
$if not "%internalizeDamages%"     == "off" activeConvMessage80("damage")                  = YES;

*** EOF ./modules/80_optimization/nash/sets.gms
