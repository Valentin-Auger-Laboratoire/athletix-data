// Vérifie que la page interactive (web/boitier-rdm/rdm.js) calcule exactement comme rdm.py.  node test_rdm.js
const path = require('path');
const RDM = require(path.join(__dirname, '../../../web/boitier-rdm/rdm.js'));
const ref = require('./resultats.json');
let n = 0, err = 0;
function cmp(a, b, chemin) {
  if (typeof b === 'number') {
    n++;
    if (!(Math.abs(a - b) <= 1e-9 * Math.max(1, Math.abs(b)))) { err++; console.log('ÉCART', chemin, a, b); }
  } else if (typeof b === 'object') for (const k of Object.keys(b)) cmp(a[k], b[k], chemin + '.' + k);
}
cmp(RDM.etude(RDM.AVANT), ref.avant, 'avant');
cmp(RDM.etude(RDM.APRES), ref.apres, 'apres');
cmp(RDM.PETG, ref.materiau, 'materiau'); cmp(RDM.CHARGES, ref.charges, 'charges');
const a = RDM.etude(RDM.APRES);
for (const [k, c, mini] of [['clip', a.clip.coef_allongement, 1.5], ['tenue', a.clip.coef_tenue, 2], ['passant 10 N', a.passant_service.coef, 2],
  ['passant 40 N', a.passant_max.coef, 1.5], ['pion', a.pion.coef, 2]]) { n++; if (c < mini) { err++; console.log('COEF TROP FAIBLE', k, c); } }
console.log(`${n} vérifications, ${err} erreur(s)`);
process.exit(err ? 1 : 0);
