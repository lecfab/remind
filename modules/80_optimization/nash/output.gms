*** |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/80_optimization/nash/output.gms

***-----------------------------------------------------------------------------
***  Write final price path to file
***  Can be used to update starting prices for Nash runs experiencing convergence
***  problems. Copy to modules/80_optimization/nash/input/prices_NASH.inc.
***-----------------------------------------------------------------------------
file prices_NASH;
put prices_NASH;
put '*** file was written by nash module, containing final price paths.';
put /;
put '*** Nash runs do not depend on it. Copy to 80_optimization/nash/input/prices_NASH.inc';
put /;
put '*** in case you experience convergence problems.';
put /;
loop(trade$(NOT tradeSe(trade)),
  loop(ttot$(ttot.val ge 2005),
    put 'p80_pvpFallback("' ttot.te(ttot):0:0 '","' trade.tl:0:0 '")='
        pm_pvp(ttot,trade):12:8 ';';
    put /;
  );
);
putclose prices_NASH;

***-----------------------------------------------------------------------------
***  Write convergence diagnostics CSV
***  Columns: Scenario | Region | Year | Iteration | Market | Surplus |
***           Price | MaxSurplus | MaxSurplusRel
***-----------------------------------------------------------------------------
file nash_info_convergence / "nash_info_convergence.csv" /;
put nash_info_convergence;
put 'Scenario', ',', 'Region', ',', 'Year', ',', 'Iteration', ',',
    'Market', ',', 'p80_surplus', ',', 'p80_pvp_itr', ',',
    'p80_surplusMax_iter', ',', 'p80_surplusMaxRel', ',':0;
put /;
loop(ttot$(ttot.val ge 2005),
  loop(iteration$(iteration.val le cm_iteration_max),
    loop(trade$(NOT tradeSe(trade)),
      put '%c_expname%', ',';
      put 'glob', ',';
      put ttot.val:0:0, ',';
      put iteration.val:0:0, ',';
      put trade.tl, ',';
      put p80_surplus(ttot,trade,iteration):12:8, ',';
      put p80_pvp_itr(ttot,trade,iteration):12:8, ',';
      put p80_surplusMax_iter(trade,iteration,ttot):12:8, ',';
      put p80_surplusMaxRel(trade,iteration,ttot):12:8, ',';
      put /;
    );
  );
);
putclose nash_info_convergence;

*** EOF ./modules/80_optimization/nash/output.gms
