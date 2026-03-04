*** |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/80_optimization/nash/declarations.gms

parameter

***-----------------------------------------------------------------------------
***  Price anticipation and adjustment elasticities
***-----------------------------------------------------------------------------
  p80_etaXp(all_enty)       "Price anticipation elasticity within one iteration (governs within-iteration price effects)"
  p80_etaLT(all_enty)       "Long-term price adjustment elasticity (between iterations, intertemporal)"
  p80_etaST(all_enty)       "Short-term price adjustment elasticity (between iterations, per time step)"
  p80_etaAdj(all_enty)      "Adjustment cost weight for changes in trade pattern between iterations"

***-----------------------------------------------------------------------------
***  Commodity market prices
***-----------------------------------------------------------------------------
  p80_pvp_itr(ttot,all_enty,iteration)        "Commodity market price per iteration [T$/TWa, T$/GtC, T$/T$]"
  p80_pvpFallback(ttot,all_enty)              "Fallback price path from input/prices_NASH.inc, used when GDX prices are missing"

***-----------------------------------------------------------------------------
***  Market volume normalization parameters
***-----------------------------------------------------------------------------
  p80_normalizeLT(all_enty)                   "Aggregated intertemporal market volume for normalization"
  p80_normalize0(ttot,all_regi,all_enty)      "Regional market volume normalization parameter"

***-----------------------------------------------------------------------------
***  Trade pattern tracking (previous iteration values)
***-----------------------------------------------------------------------------
  p80_Mport0(tall,all_regi,all_enty)          "Imports from previous iteration [TWa, T$, GtC]"
  p80_surplus(tall,all_enty,iteration)        "Residual surplus on commodity market per iteration [TWa, T$, GtC]"
  p80_defic_trade(all_enty)                   "Trade imbalance in monetary terms, summed over all time steps [trillion US$2017]"
  p80_defic_sum(iteration)                    "Total trade imbalance across all commodity markets [trillion US$2017]"
  p80_defic_sum_rel(iteration)                "Total trade imbalance as share of consumption [%]"

***-----------------------------------------------------------------------------
***  Price correction diagnostics
***-----------------------------------------------------------------------------
  p80_etaLT_correct(all_enty,iteration)       "Long-term price correction factor [fraction]"
  p80_etaST_correct(tall,all_enty,iteration)  "Short-term price correction factor [fraction]"
  p80_etaST_correct_safecopy(tall,all_enty,iteration)
                                              "Copy of short-term price correction before additional convergence adjustments"
  o80_counter_iteration_trade_ttot(ttot,all_enty,iteration)
                                              "Tracks in which iterations additional convergence push was applied"
  o80_trackSurplusSign(ttot,all_enty,iteration)
                                              "Tracks how many consecutive iterations the surplus had the same sign"
  o80_SurplusOverTolerance(ttot,all_enty,iteration)
                                              "Tracks in which iterations which market exceeded tolerance"

  p80_surplusMax_iter(all_enty,iteration,tall)    "Maximum absolute market surplus until given year, per iteration [TWa, T$, GtC]"
  p80_surplusMax2100(all_enty)               "Maximum absolute market surplus until 2100 [TWa, T$, GtC]"
  p80_surplusMaxRel(all_enty,iteration,tall) "Maximum relative market surplus until given year, per iteration [%]"
  p80_surplusMaxTolerance(all_enty)          "Maximum tolerable absolute residual market surplus in 2100 [TWa, T$, GtC]"

***-----------------------------------------------------------------------------
***  Tax revenue tracking
***-----------------------------------------------------------------------------
  p80_taxrev0(tall,all_regi)                 "Tax revenues from previous iteration [T$]"
  p80_taxrev_agg(tall,iteration)             "Global tax revenues per iteration [T$]"

***-----------------------------------------------------------------------------
***  Solver statistics and region status
***-----------------------------------------------------------------------------
  p80_handle(all_regi)                       "Parallel mode handle parameter for async solve"
  p80_repy(all_regi,solveinfo80)             "Solver statistics for each region (current iteration)"
  p80_repy_iteration(all_regi,solveinfo80,iteration)
                                             "Solver statistics per region and Nash iteration"
  p80_repyLastOptim(all_regi,solveinfo80)    "Solver statistics from the last iteration with a truly optimal solution"
  p80_repy_thisSolitr(all_regi,solveinfo80)  "Solver statistics for the current solver sub-iteration only"
  p80_repy_nashitr_solitr(all_regi,solveinfo80,iteration,sol_itr)
                                             "Full solver statistics indexed by Nash and solver iteration"
  p80_messageFailedMarket(tall,all_enty)     "Flags which markets failed to converge (display helper)"
  p80_messageShow(convMessage80)             "Flags which convergence criteria are not yet met (display helper)"
  p80_trackConsecFail(all_regi)              "Counter for consecutive solve failures per region"

***-----------------------------------------------------------------------------
***  Current account and productivity
***-----------------------------------------------------------------------------
  p80_curracc(ttot,all_regi)                 "Current account balance (exports minus imports, price-weighted)"
  pm_cumEff(tall,all_regi,all_in)            "Accumulated productivity level for learning spillover externality"

***-----------------------------------------------------------------------------
***  Price anticipation deviation diagnostics
***-----------------------------------------------------------------------------
  p80_PriceChangePriceAnticipReg(ttot,all_enty,all_regi)
                                             "Price change due to anticipation effect, per region [%]"
  o80_PriceChangePriceAnticipReg(ttot,all_enty,all_regi)
                                             "Display-only: price change due to anticipation, rounded to 0.1% [%]"
  o80_PriceChangePriceAnticipRegMaxIter(ttot,iteration)
                                             "Display-only: largest absolute anticipation price change until given year, per iteration [%]"
  p80_DevPriceAnticipReg(ttot,all_enty,all_regi)
                                             "Monetary deviation of trade expenditure due to price anticipation, per region [trillion Dollar]"
  p80_DevPriceAnticipGlob(ttot,all_enty)    "Global sum of absolute anticipation deviations per market [trillion Dollar]"
  p80_DevPriceAnticipGlobIter(ttot,all_enty,iteration)
                                             "p80_DevPriceAnticipGlob tracked over iterations [trillion Dollar]"
  p80_DevPriceAnticipGlobAll(ttot)           "p80_DevPriceAnticipGlob summed over all traded goods [trillion Dollar]"
  p80_DevPriceAnticipGlobMax(ttot,all_enty)  "Running maximum of p80_DevPriceAnticipGlob until given year [trillion Dollar]"
  p80_DevPriceAnticipGlobAllMax(ttot)        "Running maximum of p80_DevPriceAnticipGlobAll until given year [trillion Dollar]"
  p80_DevPriceAnticipGlobMax2100Iter(all_enty,iteration)
                                             "p80_DevPriceAnticipGlobMax at 2100, tracked over iterations [trillion Dollar]"
  p80_DevPriceAnticipGlobAllMax2100Iter(iteration)
                                             "p80_DevPriceAnticipGlobAllMax at 2100, tracked over iterations [trillion Dollar]"

***-----------------------------------------------------------------------------
***  EMIOPT: efficient permit allocation algorithm
***-----------------------------------------------------------------------------
  p80_eoMargPermBudg(all_regi)               "Marginal of permit budget restriction"
  p80_eoMargEmiCum(all_regi)                 "Marginal of cumulative emissions constraint"
  p80_eoMargAverage                          "Global average of marginals from Nash budget equation"
  p80_eoMargDiff(all_regi)                   "Scaled deviation of regional marginals from global average"
  p80_eoDeltaEmibudget                       "Total change in permit budget across all regions"
  p80_eoEmiMarg(all_regi)                    "Welfare-weighted marginal utility of emissions per region"
  p80_eoWeights(all_regi)                    "Welfare weights for permit budget reallocation"
  p80_eoMargDiffItr(all_regi,iteration)      "p80_eoMargDiff tracked over iterations"
  p80_eoEmibudget1RegItr(all_regi,iteration) "Regional permit budgets tracked over iterations [GtC]"
  p80_eoEmibudgetDiffAbs(iteration)          "Convergence indicator for permit budget adjustments"
  p80_count                                  "Helper: number of regions with feasible solutions"

  p80_SolNonOpt(all_regi)                    "Flag: region has a non-optimal (status 7) solve result"

  pm_fuExtrForeign(ttot,all_regi,all_enty,rlf) "Fuel extraction in all other regions (foreign supply)"

***-----------------------------------------------------------------------------
***  Iteration-level convergence tracking
***-----------------------------------------------------------------------------
  p80_convNashTaxrev_iter(iteration,ttot,all_regi)
                                             "Tax revenue relative to GDP per iteration [1]"
  p80_convNashObjVal_iter(iteration,all_regi)
                                             "Deviation of objective value from previous iteration [1]"
  p80_fadeoutPriceAnticip_iter(iteration)    "Fadeout factor for price anticipation terms, tracked over iterations"
$ifthen.cm_implicitQttyTarget not "%cm_implicitQttyTarget%" == "off"
  p80_implicitQttyTarget_dev_iter(iteration,ttot,ext_regi,qttyTarget,qttyTargetGroup)
                                             "Quantity target deviation per iteration (relative for totals, absolute for shares)"
$endif.cm_implicitQttyTarget
  p80_globalBudget_absDev_iter(iteration)    "Absolute deviation of global cumulative CO2 from target budget [GtC]"
  p80_regionalBudget_absDev_iter(iteration,all_regi)
                                             "Absolute deviation of regional CO2 target budgets [GtC]"
  p80_sccConvergenceMaxDeviation_iter(iteration)
                                             "Maximum SCC deviation from previous iteration [%]"
  p80_gmt_conv_iter(iteration)               "Global mean temperature convergence indicator per iteration"
;

positive variable
*** Adjustment costs penalizing deviations from the previous iteration's trade pattern.
*** These costs are only non-zero in the Nash realization of module 80_optimization.
  vm_costAdjNash(ttot,all_regi)  "Quadratic adjustment costs for trade pattern changes between iterations [T$]"
;

equations
  q80_budg_intertemp(all_regi)    "Intertemporal trade balance (Nash mode only)"
  q80_costAdjNash(ttot,all_regi)  "Quadratic Nash adjustment costs across all markets"
  q80_budgetPermRestr(all_regi)   "Regional permit budget constraint"
;

scalars
  sm_fadeoutPriceAnticip              "Fadeout factor for price anticipation (1 = full, 0 = off)"
  s80_fadeoutPriceAnticipStartingPeriod
                                      "Iteration in which price anticipation fadeout begins (0 = not started)"
  s80_before                          "Helper: time step value before current interpolation time step"
  s80_after                           "Helper: time step value after current interpolation time step"
  s80_numberIterations                "Display helper: total number of Nash iterations"
  s80_nashConverging                  "Convergence flag: 1 if all active convergence criteria are met, 0 otherwise"
  s80_converged                       "Final convergence flag: set to 1 when Nash fully converges"
  s80_runInDebug                      "Flag: 1 if regions are being re-solved in debug mode after consecutive failures" /0/
;

*** Define display precision for key diagnostic parameters
option p80_DevPriceAnticipGlobAll:3:0:1;
option p80_DevPriceAnticipGlobAllMax:3:0:1;
option o80_PriceChangePriceAnticipReg:1:2:1;
option o80_PriceChangePriceAnticipRegMaxIter:1:1:1;

*** EOF ./modules/80_optimization/nash/declarations.gms
