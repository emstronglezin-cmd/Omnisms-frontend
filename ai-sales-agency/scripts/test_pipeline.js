#!/usr/bin/env node
// ============================================================
// AI Sales Agency — Script de test complet
// Usage: node scripts/test_pipeline.js
// ============================================================
const Pipeline = require('../automation/pipeline');
const config = require('../config');

async function main() {
  console.log('\n' + '═'.repeat(60));
  console.log('🧪 AI SALES AGENCY — TEST PIPELINE COMPLET');
  console.log('═'.repeat(60));
  console.log(`📅 Date: ${new Date().toLocaleString('fr-FR')}`);
  console.log(`🔧 Config:`);
  console.log(`   - Supabase: ${config.supabase.url ? '✅' : '❌ Non configuré'}`);
  console.log(`   - Gmail: ${config.gmail.refreshToken ? '✅' : '⚠️  Non configuré (emails simulés)'}`);
  console.log(`   - OpenAI: ${config.openai.apiKey ? '✅' : '⚠️  Non configuré (templates actifs)'}`);
  console.log(`   - Mode test: ${config.app.testMode ? '✅ OUI' : '❌ NON (vrais emails!)'}`);
  console.log('═'.repeat(60) + '\n');

  const pipeline = new Pipeline();

  try {
    const rapport = await pipeline.lancerPremierTest({
      nombre: 10,
      ville: 'Lyon',
      secteurs: ['restaurant', 'commerce', 'artisan'],
      source: config.googleMaps.apiKey ? 'google_maps' : 'simulation',
    });

    console.log('\n📊 RAPPORT FINAL:');
    console.log('─'.repeat(60));
    console.log(`✅ Leads prospectés: ${rapport.stats?.leads_prospectes}`);
    console.log(`📊 Leads scorés: ${rapport.stats?.leads_scores}`);
    console.log(`✍️  Stratégies créées: ${rapport.stats?.strategies_creees}`);
    console.log(`📧 Emails ${config.app.testMode ? 'simulés' : 'envoyés'}: ${rapport.stats?.emails_envoyes}`);
    console.log(`❌ Erreurs: ${rapport.stats?.errors?.length || 0}`);

    if (rapport.leads?.length > 0) {
      console.log('\n👥 LEADS TROUVÉS:');
      rapport.leads.forEach((l, i) => {
        console.log(`${i + 1}. ${l.entreprise} (${l.ville}) — Score: ${l.score}/100 — ${l.statut}`);
        if (l.probleme) console.log(`   └─ ${l.probleme}`);
      });
    }

    if (rapport.stats?.errors?.length > 0) {
      console.log('\n❌ ERREURS:');
      rapport.stats.errors.forEach(e => {
        console.log(`  - ${e.lead}: ${e.erreur}`);
      });
    }

    console.log('\n' + '═'.repeat(60));
    console.log('🏁 Test terminé avec succès!');
    if (config.app.testMode) {
      console.log('\n⚠️  RAPPEL: Emails simulés (TEST_MODE=true)');
      console.log('   Pour envoyer de vrais emails:');
      console.log('   1. node gmail/auth.js (obtenir refresh token)');
      console.log('   2. TEST_MODE=false dans .env');
      console.log('   3. Relancer: node scripts/test_pipeline.js');
    }
    console.log('═'.repeat(60) + '\n');

    process.exit(0);
  } catch (err) {
    console.error('\n❌ ERREUR CRITIQUE:', err.message);
    console.error(err.stack);
    process.exit(1);
  }
}

main();
