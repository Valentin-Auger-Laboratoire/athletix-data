// Étude RDM du boîtier d'Athletix-Data (Valentin Auger) : mêmes formules que hardware/boitier/rdm/rdm.py.
(function (racine) {
  'use strict';
  const PETG = { E: 2000, sigma_plan: 45, sigma_travers: 25, eps_plan: 2.0, eps_travers: 1.0, mu: 0.3 };
  const CHARGES = { acc_g: 10, masse_poussee_g: 62, mousse_N: 2, T_service_N: 10, T_max_N: 40, R_bras_mm: 50, F_bouchon_N: 10 };
  const AVANT = {
    clip: { L: 9, t: 1.2, b: 8, bec: 0.9, jeu: 0.3, n: 7 },
    passant: { portee: 51, barre_y: 1.2, barre_z: 3.0, fente_centre: 4.8 },
    pion: { type: 'fendu', tige_d: 2.6, tete_d: 3.8, trou_d: 3.0, fente_l: 3.4, fente: 0.7 },
  };
  const APRES = {
    clip: { L: 9, t: 1.0, b: 8, bec: 0.65, jeu: 0.3, n: 7 },
    passant: { portee: 51, barre_y: 4.0, barre_z: 3.5, fente_centre: 4.5 },
    pion: { type: 'baionnette', tige_d: 3.0, tige_l: 3.6, aile_r: 3.0, aile_l: 2.0, aile_ep: 2.0 },
  };
  const BOITE = { ext_y: 43, h_couvercle: 29 };

  function clip(g, m = PETG, ch = CHARGES) {
    const y = g.bec - g.jeu;
    const eps = 1.5 * g.t * y / (g.L * g.L) * 100;
    const I = g.b * g.t ** 3 / 12;
    const P = 3 * m.E * I * y / g.L ** 3;
    const rampe = Math.atan(g.bec / 2), retenue = Math.PI / 4, mu = m.mu;
    const Win = P * (mu + Math.tan(rampe)) / (1 - mu * Math.tan(rampe));
    const Wout = P * (mu + Math.tan(retenue)) / (1 - mu * Math.tan(retenue));
    const besoin = ch.masse_poussee_g / 1000 * 9.81 * ch.acc_g + ch.mousse_N;
    return { fleche_mm: y, allongement_pct: eps, allongement_admis_pct: m.eps_travers, coef_allongement: m.eps_travers / eps,
      effort_flexion_N: P, fermeture_N: Win * g.n, ouverture_N: Wout * g.n, besoin_N: besoin, coef_tenue: Wout * g.n / besoin };
  }
  function deviationBande(g, ch = CHARGES) {
    const yf = BOITE.ext_y / 2 + g.fente_centre;
    const haut = [BOITE.ext_y / 2 + 0.5, BOITE.h_couvercle];
    const d1 = [yf - haut[0], 0 - haut[1]];
    const R = ch.R_bras_mm;
    const cz = -Math.sqrt(Math.max(R * R - yf * yf, 1));
    const r = [yf, 0 - cz];
    let t = [r[1], -r[0]];
    if (t[1] > 0) t = [-t[0], -t[1]];
    const n1 = Math.hypot(...d1), n2 = Math.hypot(...t);
    const u1 = [d1[0] / n1, d1[1] / n1], u2 = [t[0] / n2, t[1] / n2];
    const delta = Math.acos(Math.max(-1, Math.min(1, u1[0] * u2[0] + u1[1] * u2[1])));
    return { delta, f: [-(u2[0] - u1[0]), -(u2[1] - u1[1])], yf, haut, tangente: u2 };
  }
  function passant(g, T, m = PETG, ch = CHARGES) {
    const d = deviationBande(g, ch);
    const Ry = Math.abs(d.f[0]) * T, Rz = Math.abs(d.f[1]) * T;
    const L = g.portee, by = g.barre_y, bz = g.barre_z;
    const Wy = bz * by * by / 6, Wz = by * bz * bz / 6;
    const sigma = (Ry * L / 12) / Wy + (Rz * L / 12) / Wz;
    const Iy = bz * by ** 3 / 12;
    return { T_N: T, deviation_deg: d.delta * 180 / Math.PI, R_N: Math.hypot(Ry, Rz), contrainte_MPa: sigma,
      fleche_mm: Ry * L ** 3 / (384 * m.E * Iy), admis_MPa: m.sigma_plan, coef: sigma > 0 ? m.sigma_plan / sigma : Infinity };
  }
  function pion(g, m = PETG, ch = CHARGES) {
    if (g.type === 'fendu') {
      const t = g.tige_d / 2 - g.fente / 2, y = (g.tete_d - g.trou_d) / 2;
      const eps = 1.5 * t * y / g.fente_l ** 2 * 100;
      return { type: 'fendu', allongement_pct: eps, admis_pct: m.eps_plan, coef: m.eps_plan / eps };
    }
    const F = ch.F_bouchon_N, d = g.tige_d, l = g.tige_l;
    const sTige = 32 * F * l / (Math.PI * d ** 3);
    const sAile = F * (g.aile_r - d / 2) / (g.aile_l * g.aile_ep ** 2 / 6);
    return { type: 'baionnette', tige_MPa: sTige, coef_tige: m.sigma_plan / sTige, aile_MPa: sAile,
      coef_aile: m.sigma_travers / sAile, coef: Math.min(m.sigma_plan / sTige, m.sigma_travers / sAile) };
  }
  function etude(geo, m = PETG, ch = CHARGES) {
    return { clip: clip(geo.clip, m, ch), passant_service: passant(geo.passant, ch.T_service_N, m, ch),
      passant_max: passant(geo.passant, ch.T_max_N, m, ch), pion: pion(geo.pion, m, ch) };
  }
  const api = { PETG, CHARGES, AVANT, APRES, BOITE, clip, deviationBande, passant, pion, etude };
  if (typeof module !== 'undefined' && module.exports) module.exports = api; else racine.RDM = api;
})(typeof window !== 'undefined' ? window : globalThis);
