*** |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/80_optimization/nashOneRegi/realization.gms

*' @description
*' Like nash mode, each selected region (c_testOneRegi_region, set regi_dyn80) forms its own
*' optimisation problem and trades on goods and resource markets. Unlike nash mode, other regions
*' are NOT re-optimized: their trade, production and tax variables are taken from, and stay
*' fixed at, the values found in the reference gdx (input.gdx) - which must be an already
*' converged global nash run. World prices (pm_pvp) and the global carbon-price anchor are
*' likewise taken from that reference and never updated.
*'
*' This is intended for studies where the selected region(s) are assumed too small to move global
*' prices or the global carbon budget: many scenario variants can then be produced by only
*' solving the selected region(s) against one shared, already-converged world, needing just a
*' few iterations for the targets to be met: tax convergence, NDC/regional budget, implicit targets...
*'
*' @limitations The "small region" assumption is not checked: if the selected region(s) are in fact
*' large enough to move world prices or the global carbon budget noticeably, this realisation will
*' silently ignore that feedback. Emission-market or quantity-target groups spanning a studied
*' region together with a frozen region cannot be validly re-checked for convergence here.

*####################### R SECTION START (PHASES) ##############################
$Ifi "%phase%" == "sets" $include "./modules/80_optimization/nashOneRegi/sets.gms"
$Ifi "%phase%" == "declarations" $include "./modules/80_optimization/nashOneRegi/declarations.gms"
$Ifi "%phase%" == "datainput" $include "./modules/80_optimization/nashOneRegi/datainput.gms"
$Ifi "%phase%" == "equations" $include "./modules/80_optimization/nashOneRegi/equations.gms"
$Ifi "%phase%" == "preloop" $include "./modules/80_optimization/nashOneRegi/preloop.gms"
$Ifi "%phase%" == "bounds" $include "./modules/80_optimization/nashOneRegi/bounds.gms"
$Ifi "%phase%" == "presolve" $include "./modules/80_optimization/nashOneRegi/presolve.gms"
$Ifi "%phase%" == "solve" $include "./modules/80_optimization/nashOneRegi/solve.gms"
$Ifi "%phase%" == "postsolve" $include "./modules/80_optimization/nashOneRegi/postsolve.gms"
$Ifi "%phase%" == "output" $include "./modules/80_optimization/nashOneRegi/output.gms"
*######################## R SECTION END (PHASES) ###############################
*** EOF ./modules/80_optimization/nashOneRegi/realization.gms
