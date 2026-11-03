const test = require('node:test');
const assert = require('node:assert/strict');
const {templateData, instanceData, approved} = require('../migrate/backfill-procedure-tags');
test('snapshot preserves full catalog and approved line independently', () => {
  const definition = templateData({clinicId:'c',name:'Resina',price:250,commissionValue:40,hasCost:true}, 'proc');
  const args = {clinicId:'c',patientId:'p',budgetId:'b',planId:'plan',index:0,line:{id:'proc',name:'Resina',price:200,quantity:2,region:'22'},definition,planItem:{status:'pendente'},planStatus:'active'};
  const tag = instanceData(args);
  assert.equal(tag.lineSnapshot.price,200); assert.equal(tag.definitionSnapshot.procedureSnapshot.price,250);
  assert.equal(tag.status,'pending'); assert.equal(tag.sessionCount,0);
  assert.notEqual(instanceData({...args,budgetId:'other'}).budgetId,tag.budgetId);
});
test('historical closure is not invented completion or session history', () => {
  const args = {clinicId:'c',patientId:'p',budgetId:'b',planId:'plan',index:0,line:{name:'Procedimento'},definition:{},planStatus:'completed'};
  assert.equal(instanceData(args).status,'legacy_closed');
  assert.equal(instanceData({...args,planItem:{status:'completed'}}).status,'completed');
  assert.equal(approved({status:'Aprovado'}),true); assert.equal(approved({status:'Pendente'}),false);
});
