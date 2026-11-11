*** |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/80_optimization/nashOneRegi/sets.gms

sets
learnte_dyn80(all_te)   "learnte for nash"
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

solveinfo80	"Nash solution stats"
/
solvestat, modelstat, resusd, objval
/

convMessage80   "contains all convergence criteria"
/
infes,surplus,nonopt,taxconv,anticip,globalbudget,peakbudgyr,peakbudget,regiBudget,regiTarget,NDC,implicitEnergyTarget,cm_implicitPriceTarget,cm_implicitPePriceTarget,damage,DevPriceAnticip, IterationNumber
/

activeConvMessage80(convMessage80)   "all active convergence criterias" / /

*LB*AJS* regions re-optimized against an otherwise fixed (frozen) world, taken from the gdx
regi_dyn80_list(all_regi) "regions to be re-optimized, read from c_testOneRegi_region" / %c_testOneRegi_region% /,
regi_dyn80(all_regi)      "regions to be re-optimized against a fixed rest-of-world"
;

teLearn(learnte_dyn80)   = YES;

regi_dyn80(all_regi) = NO;
regi_dyn80(regi_dyn80_list) = YES;

activeConvMessage80("infes") = YES;
activeConvMessage80("nonopt") = YES;
activeConvMessage80("IterationNumber") = YES;

*** world prices/quantities are fixed from the reference gdx and never updated in postsolve,
*** so the trade-surplus and price-anticipation convergence criteria (which only make sense
*** while prices are still being adjusted) are not evaluated here.
***activeConvMessage80("surplus") = YES;
***activeConvMessage80("anticip") = YES;
***activeConvMessage80("DevPriceAnticip") = YES;

if (cm_TaxConvCheck eq 1, activeConvMessage80("taxconv") = YES;);
activeConvMessage80("globalbudget") = YES;
$if %carbonprice% == "functionalForm" activeConvMessage80("peakbudgyr") = YES;
$if %carbonprice% == "functionalForm" activeConvMessage80("peakbudget") = YES;
$if not "%cm_emiMktTarget%" == "off" activeConvMessage80("regiTarget") = YES;
$if not "%cm_implicitQttyTarget%" == "off" activeConvMessage80("implicitEnergyTarget") = YES;
$if not "%cm_implicitPriceTarget%" == "off" activeConvMessage80("cm_implicitPriceTarget") = YES;
$if not "%cm_implicitPePriceTarget%" == "off" activeConvMessage80("cm_implicitPePriceTarget") = YES;
$if not "%internalizeDamages%" == "off" activeConvMessage80("damage") = YES;

display teLearn;
display regi_dyn80;
*** EOF ./modules/80_optimization/nashOneRegi/sets.gms
