*** |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/80_optimization/nash/preloop.gms

***-----------------------------------------------------------------------------
***  Load initial price and trade data from input GDX
***-----------------------------------------------------------------------------
Execute_Loadpoint 'input' pm_pvp      = pm_pvp;
Execute_Loadpoint 'input' vm_Xport.l  = vm_Xport.l;
Execute_Loadpoint 'input' vm_Mport.l  = vm_Mport.l;
Execute_Loadpoint 'input' vm_cons.l   = vm_cons.l;
Execute_Loadpoint 'input' vm_taxrev.l = vm_taxrev.l;
Execute_Loadpoint 'input' vm_fuExtr.l = vm_fuExtr.l;
Execute_Loadpoint 'input' vm_prodPe.l = vm_prodPe.l;

*** Initialize solver statistics with NA to signal that no solve has occurred yet
p80_repyLastOptim(regi,solveinfo80) = NA;

***-----------------------------------------------------------------------------
***  Initialize starting prices from GDX
***  If a price is missing (NA), zero, or unreasonably large (>0.1), fall back
***  to the price path stored in input/prices_NASH.inc.
***  If still NA after fallback, set to zero.
***-----------------------------------------------------------------------------
loop(ttot$(ttot.val ge 2005),
  loop(trade$(NOT tradeSe(trade)),
    if (   (pm_pvp(ttot,trade) eq NA)
        OR (pm_pvp(ttot,trade) lt 1E-12)
        OR (pm_pvp(ttot,trade) gt 0.1),
      pm_pvp(ttot,trade) = p80_pvpFallback(ttot,trade);
      display 'Nash: Info: Could not load useful initial price from gdx, falling back to the one found in input/prices_NASH.inc. This should not be a problem, the runs can still converge. ';
    );
    if (pm_pvp(ttot,trade) eq NA,
      pm_pvp(ttot,trade) = 0;
    );
  );
);

***-----------------------------------------------------------------------------
***  Initialize trade pattern and normalization from GDX
***  Zero out any NA values for imports and exports.
***-----------------------------------------------------------------------------
loop(ttot$(ttot.val ge 2005),
  loop(trade$(NOT tradeSe(trade)),
    loop(regi,
      pm_Xport0(ttot,regi,trade)  = vm_Xport.l(ttot,regi,trade);
      p80_Mport0(ttot,regi,trade) = vm_Mport.l(ttot,regi,trade);

      if (pm_Xport0(ttot,regi,trade) eq NA,
        pm_Xport0(ttot,regi,trade)     = 0;
        vm_Xport.l(ttot,regi,trade)    = 0;
      );
      if (p80_Mport0(ttot,regi,trade) eq NA,
        p80_Mport0(ttot,regi,trade)    = 0;
        vm_Mport.l(ttot,regi,trade)    = 0;
      );

      *** Normalization: scale adjustment costs to meaningful quantities
      p80_normalize0(ttot,regi,"good")  = vm_cons.l(ttot,regi);
      p80_normalize0(ttot,regi,"perm")$(ttot.val ge 2005)
        = max(abs(pm_shPerm(ttot,regi) * pm_emicapglob(ttot)), 1E-6);
      p80_normalize0(ttot,regi,tradePe)
        = 0.5 * (sum(rlf, vm_fuExtr.l(ttot,regi,tradePe,rlf)) + vm_prodPe.l(ttot,regi,tradePe));

      p80_taxrev0(ttot,regi) = vm_taxrev.l(ttot,regi);
    );
  );
);

*** Handle any remaining NA values for 2005 imports of primary energy
loop(regi,
  loop(tradePe,
    if (p80_Mport0("2005",regi,tradePe) eq NA,
      p80_Mport0("2005",regi,tradePe) = 0;
    );
  );
);

***-----------------------------------------------------------------------------
***  Initialize permit prices
***  Starting a policy run from zero permit prices leads to numerical problems.
***  Use a $30/tCO2eq in 2020 price trajectory as the default starting path.
***-----------------------------------------------------------------------------
if (   (cm_emiscen ne 1)
   AND (cm_emiscen ne 9)
   AND (smax(t, pm_pvp(t,"perm")) eq 0),
  loop(ttot$(ttot.val ge 2005),
    *** $30/tCO2eq in 2020, growing at 5%/yr
    pm_pvp(ttot,"perm") = 0.11 * 1.05**(ttot.val - 2020) * pm_pvp(ttot,"good");
  );
  pm_pvp("2005","perm") = 0;
);

*** In BAU and reference scenarios, no permit trading occurs
if ((cm_emiscen eq 1) OR (cm_emiscen eq 9),
  pm_pvp(ttot,"perm") = 0;
);

***-----------------------------------------------------------------------------
***  Record iteration-1 price path for diagnostics
***-----------------------------------------------------------------------------
p80_pvp_itr(ttot,trade,"1")$(NOT tradeSe(trade)) = pm_pvp(ttot,trade);

***-----------------------------------------------------------------------------
***  Patch zero resource prices (e.g. 2150, peur) by carrying forward
***  the last known non-zero price, to avoid convergence problems.
***-----------------------------------------------------------------------------
loop(tradePe,
  loop(ttot$(NOT sameas(ttot,'2005')),
    if (p80_pvp_itr(ttot,tradePe,"1") eq 0,
      p80_pvp_itr(ttot,tradePe,"1") = p80_pvp_itr(ttot-1,tradePe,"1")$(NOT sameas(ttot,'2005'));
    );
  );
);

***-----------------------------------------------------------------------------
***  Debug display
***-----------------------------------------------------------------------------
display pm_pvp, p80_normalize0;
display pm_Xport0, p80_Mport0;
display p80_surplusMaxTolerance;

***-----------------------------------------------------------------------------
***  EMIOPT: set initial regional permit budgets from global budget and shares
***-----------------------------------------------------------------------------
$ifthen.emiopt %emicapregi% == 'none'
if (cm_emiscen eq 6,
  pm_budgetCO2eq(regi) = pm_shPerm("2050",regi) * sm_budgetCO2eqGlob;
  display pm_shPerm, sm_budgetCO2eqGlob, pm_budgetCO2eq;
);
$endif.emiopt

*** EOF ./modules/80_optimization/nash/preloop.gms
