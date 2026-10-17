// Generated from contracts/revision-v1.schema.json; npm run generate:validator.
"use strict";
export const validate = validate20;
export default validate20;
const schema31 = {"$schema":"https://json-schema.org/draft/2020-12/schema","$id":"https://nexmob.dev/contracts/revision-v1.schema.json","title":"RevisionV1","description":"Manifesto imutável de uma revisão sincronizada do projeto Nex Mob.","type":"object","additionalProperties":false,"required":["schema_version","project_id","revision_id","synced_at","modules"],"properties":{"schema_version":{"const":"1"},"project_id":{"type":"string","minLength":1},"revision_id":{"type":"string","minLength":1},"synced_at":{"type":"string","pattern":"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$"},"modules":{"type":"array","items":{"$ref":"#/$defs/module"}}},"$defs":{"module":{"type":"object","additionalProperties":false,"required":["module_id","name","environment","pieces"],"properties":{"module_id":{"type":"string","minLength":1},"name":{"type":"string","minLength":1},"environment":{"type":"string"},"pieces":{"type":"array","items":{"$ref":"#/$defs/piece"}}}},"piece":{"type":"object","additionalProperties":false,"required":["logical_key","qr_token","name","cut_mm","transform_mm","material","edge_banding","visible"],"properties":{"logical_key":{"type":"string","minLength":1},"qr_token":{"type":"string","pattern":"^[0-9a-fA-F]{32}$"},"name":{"type":"string","minLength":1},"cut_mm":{"type":"array","items":{"type":"number","exclusiveMinimum":0},"minItems":3,"maxItems":3},"transform_mm":{"type":"array","items":{"type":"number"},"minItems":4,"maxItems":4,"description":"[x, y, z, rotation_z_deg], with translation in millimeters."},"material":{"type":"string","minLength":1},"edge_banding":{"type":"object","additionalProperties":false,"required":["top","right","bottom","left"],"properties":{"top":{"type":"boolean"},"right":{"type":"boolean"},"bottom":{"type":"boolean"},"left":{"type":"boolean"}}},"visible":{"type":"boolean"}}}}};
const func1 = require("ajv/dist/runtime/ucs2length").default;
const pattern4 = new RegExp("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$", "u");
const schema32 = {"type":"object","additionalProperties":false,"required":["module_id","name","environment","pieces"],"properties":{"module_id":{"type":"string","minLength":1},"name":{"type":"string","minLength":1},"environment":{"type":"string"},"pieces":{"type":"array","items":{"$ref":"#/$defs/piece"}}}};
const schema33 = {"type":"object","additionalProperties":false,"required":["logical_key","qr_token","name","cut_mm","transform_mm","material","edge_banding","visible"],"properties":{"logical_key":{"type":"string","minLength":1},"qr_token":{"type":"string","pattern":"^[0-9a-fA-F]{32}$"},"name":{"type":"string","minLength":1},"cut_mm":{"type":"array","items":{"type":"number","exclusiveMinimum":0},"minItems":3,"maxItems":3},"transform_mm":{"type":"array","items":{"type":"number"},"minItems":4,"maxItems":4,"description":"[x, y, z, rotation_z_deg], with translation in millimeters."},"material":{"type":"string","minLength":1},"edge_banding":{"type":"object","additionalProperties":false,"required":["top","right","bottom","left"],"properties":{"top":{"type":"boolean"},"right":{"type":"boolean"},"bottom":{"type":"boolean"},"left":{"type":"boolean"}}},"visible":{"type":"boolean"}}};
const pattern5 = new RegExp("^[0-9a-fA-F]{32}$", "u");

function validate21(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate21.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.module_id === undefined) && (missing0 = "module_id")) || ((data.name === undefined) && (missing0 = "name"))) || ((data.environment === undefined) && (missing0 = "environment"))) || ((data.pieces === undefined) && (missing0 = "pieces"))){
validate21.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "module_id") || (key0 === "name")) || (key0 === "environment")) || (key0 === "pieces"))){
validate21.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.module_id !== undefined){
let data0 = data.module_id;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func1(data0) < 1){
validate21.errors = [{instancePath:instancePath+"/module_id",schemaPath:"#/properties/module_id/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
}
else {
validate21.errors = [{instancePath:instancePath+"/module_id",schemaPath:"#/properties/module_id/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.name !== undefined){
let data1 = data.name;
const _errs4 = errors;
if(errors === _errs4){
if(typeof data1 === "string"){
if(func1(data1) < 1){
validate21.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
}
else {
validate21.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.environment !== undefined){
const _errs6 = errors;
if(typeof data.environment !== "string"){
validate21.errors = [{instancePath:instancePath+"/environment",schemaPath:"#/properties/environment/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.pieces !== undefined){
let data3 = data.pieces;
const _errs8 = errors;
if(errors === _errs8){
if(Array.isArray(data3)){
var valid1 = true;
const len0 = data3.length;
for(let i0=0; i0<len0; i0++){
let data4 = data3[i0];
const _errs10 = errors;
const _errs11 = errors;
if(errors === _errs11){
if(data4 && typeof data4 == "object" && !Array.isArray(data4)){
let missing1;
if(((((((((data4.logical_key === undefined) && (missing1 = "logical_key")) || ((data4.qr_token === undefined) && (missing1 = "qr_token"))) || ((data4.name === undefined) && (missing1 = "name"))) || ((data4.cut_mm === undefined) && (missing1 = "cut_mm"))) || ((data4.transform_mm === undefined) && (missing1 = "transform_mm"))) || ((data4.material === undefined) && (missing1 = "material"))) || ((data4.edge_banding === undefined) && (missing1 = "edge_banding"))) || ((data4.visible === undefined) && (missing1 = "visible"))){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0,schemaPath:"#/$defs/piece/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs13 = errors;
for(const key1 in data4){
if(!((((((((key1 === "logical_key") || (key1 === "qr_token")) || (key1 === "name")) || (key1 === "cut_mm")) || (key1 === "transform_mm")) || (key1 === "material")) || (key1 === "edge_banding")) || (key1 === "visible"))){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0,schemaPath:"#/$defs/piece/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs13 === errors){
if(data4.logical_key !== undefined){
let data5 = data4.logical_key;
const _errs14 = errors;
if(errors === _errs14){
if(typeof data5 === "string"){
if(func1(data5) < 1){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/logical_key",schemaPath:"#/$defs/piece/properties/logical_key/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
}
else {
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/logical_key",schemaPath:"#/$defs/piece/properties/logical_key/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid3 = _errs14 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.qr_token !== undefined){
let data6 = data4.qr_token;
const _errs16 = errors;
if(errors === _errs16){
if(typeof data6 === "string"){
if(!pattern5.test(data6)){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/qr_token",schemaPath:"#/$defs/piece/properties/qr_token/pattern",keyword:"pattern",params:{pattern: "^[0-9a-fA-F]{32}$"},message:"must match pattern \""+"^[0-9a-fA-F]{32}$"+"\""}];
return false;
}
}
else {
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/qr_token",schemaPath:"#/$defs/piece/properties/qr_token/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid3 = _errs16 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.name !== undefined){
let data7 = data4.name;
const _errs18 = errors;
if(errors === _errs18){
if(typeof data7 === "string"){
if(func1(data7) < 1){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/name",schemaPath:"#/$defs/piece/properties/name/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
}
else {
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/name",schemaPath:"#/$defs/piece/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid3 = _errs18 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.cut_mm !== undefined){
let data8 = data4.cut_mm;
const _errs20 = errors;
if(errors === _errs20){
if(Array.isArray(data8)){
if(data8.length > 3){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/cut_mm",schemaPath:"#/$defs/piece/properties/cut_mm/maxItems",keyword:"maxItems",params:{limit: 3},message:"must NOT have more than 3 items"}];
return false;
}
else {
if(data8.length < 3){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/cut_mm",schemaPath:"#/$defs/piece/properties/cut_mm/minItems",keyword:"minItems",params:{limit: 3},message:"must NOT have fewer than 3 items"}];
return false;
}
else {
var valid4 = true;
const len1 = data8.length;
for(let i1=0; i1<len1; i1++){
let data9 = data8[i1];
const _errs22 = errors;
if(errors === _errs22){
if((typeof data9 == "number") && (isFinite(data9))){
if(data9 <= 0 || isNaN(data9)){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/cut_mm/" + i1,schemaPath:"#/$defs/piece/properties/cut_mm/items/exclusiveMinimum",keyword:"exclusiveMinimum",params:{comparison: ">", limit: 0},message:"must be > 0"}];
return false;
}
}
else {
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/cut_mm/" + i1,schemaPath:"#/$defs/piece/properties/cut_mm/items/type",keyword:"type",params:{type: "number"},message:"must be number"}];
return false;
}
}
var valid4 = _errs22 === errors;
if(!valid4){
break;
}
}
}
}
}
else {
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/cut_mm",schemaPath:"#/$defs/piece/properties/cut_mm/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid3 = _errs20 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.transform_mm !== undefined){
let data10 = data4.transform_mm;
const _errs24 = errors;
if(errors === _errs24){
if(Array.isArray(data10)){
if(data10.length > 4){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/transform_mm",schemaPath:"#/$defs/piece/properties/transform_mm/maxItems",keyword:"maxItems",params:{limit: 4},message:"must NOT have more than 4 items"}];
return false;
}
else {
if(data10.length < 4){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/transform_mm",schemaPath:"#/$defs/piece/properties/transform_mm/minItems",keyword:"minItems",params:{limit: 4},message:"must NOT have fewer than 4 items"}];
return false;
}
else {
var valid5 = true;
const len2 = data10.length;
for(let i2=0; i2<len2; i2++){
let data11 = data10[i2];
const _errs26 = errors;
if(!((typeof data11 == "number") && (isFinite(data11)))){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/transform_mm/" + i2,schemaPath:"#/$defs/piece/properties/transform_mm/items/type",keyword:"type",params:{type: "number"},message:"must be number"}];
return false;
}
var valid5 = _errs26 === errors;
if(!valid5){
break;
}
}
}
}
}
else {
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/transform_mm",schemaPath:"#/$defs/piece/properties/transform_mm/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid3 = _errs24 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.material !== undefined){
let data12 = data4.material;
const _errs28 = errors;
if(errors === _errs28){
if(typeof data12 === "string"){
if(func1(data12) < 1){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/material",schemaPath:"#/$defs/piece/properties/material/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
}
else {
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/material",schemaPath:"#/$defs/piece/properties/material/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid3 = _errs28 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.edge_banding !== undefined){
let data13 = data4.edge_banding;
const _errs30 = errors;
if(errors === _errs30){
if(data13 && typeof data13 == "object" && !Array.isArray(data13)){
let missing2;
if(((((data13.top === undefined) && (missing2 = "top")) || ((data13.right === undefined) && (missing2 = "right"))) || ((data13.bottom === undefined) && (missing2 = "bottom"))) || ((data13.left === undefined) && (missing2 = "left"))){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/edge_banding",schemaPath:"#/$defs/piece/properties/edge_banding/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"}];
return false;
}
else {
const _errs32 = errors;
for(const key2 in data13){
if(!((((key2 === "top") || (key2 === "right")) || (key2 === "bottom")) || (key2 === "left"))){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/edge_banding",schemaPath:"#/$defs/piece/properties/edge_banding/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs32 === errors){
if(data13.top !== undefined){
const _errs33 = errors;
if(typeof data13.top !== "boolean"){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/edge_banding/top",schemaPath:"#/$defs/piece/properties/edge_banding/properties/top/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid6 = _errs33 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data13.right !== undefined){
const _errs35 = errors;
if(typeof data13.right !== "boolean"){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/edge_banding/right",schemaPath:"#/$defs/piece/properties/edge_banding/properties/right/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid6 = _errs35 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data13.bottom !== undefined){
const _errs37 = errors;
if(typeof data13.bottom !== "boolean"){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/edge_banding/bottom",schemaPath:"#/$defs/piece/properties/edge_banding/properties/bottom/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid6 = _errs37 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data13.left !== undefined){
const _errs39 = errors;
if(typeof data13.left !== "boolean"){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/edge_banding/left",schemaPath:"#/$defs/piece/properties/edge_banding/properties/left/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid6 = _errs39 === errors;
}
else {
var valid6 = true;
}
}
}
}
}
}
}
else {
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/edge_banding",schemaPath:"#/$defs/piece/properties/edge_banding/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid3 = _errs30 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.visible !== undefined){
const _errs41 = errors;
if(typeof data4.visible !== "boolean"){
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0+"/visible",schemaPath:"#/$defs/piece/properties/visible/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid3 = _errs41 === errors;
}
else {
var valid3 = true;
}
}
}
}
}
}
}
}
}
}
}
else {
validate21.errors = [{instancePath:instancePath+"/pieces/" + i0,schemaPath:"#/$defs/piece/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid1 = _errs10 === errors;
if(!valid1){
break;
}
}
}
else {
validate21.errors = [{instancePath:instancePath+"/pieces",schemaPath:"#/properties/pieces/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
}
}
}
}
}
}
else {
validate21.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate21.errors = vErrors;
return errors === 0;
}
validate21.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate20(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
/*# sourceURL="https://nexmob.dev/contracts/revision-v1.schema.json" */;
let vErrors = null;
let errors = 0;
const evaluated0 = validate20.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.schema_version === undefined) && (missing0 = "schema_version")) || ((data.project_id === undefined) && (missing0 = "project_id"))) || ((data.revision_id === undefined) && (missing0 = "revision_id"))) || ((data.synced_at === undefined) && (missing0 = "synced_at"))) || ((data.modules === undefined) && (missing0 = "modules"))){
validate20.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "schema_version") || (key0 === "project_id")) || (key0 === "revision_id")) || (key0 === "synced_at")) || (key0 === "modules"))){
validate20.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.schema_version !== undefined){
const _errs2 = errors;
if("1" !== data.schema_version){
validate20.errors = [{instancePath:instancePath+"/schema_version",schemaPath:"#/properties/schema_version/const",keyword:"const",params:{allowedValue: "1"},message:"must be equal to constant"}];
return false;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.project_id !== undefined){
let data1 = data.project_id;
const _errs3 = errors;
if(errors === _errs3){
if(typeof data1 === "string"){
if(func1(data1) < 1){
validate20.errors = [{instancePath:instancePath+"/project_id",schemaPath:"#/properties/project_id/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
}
else {
validate20.errors = [{instancePath:instancePath+"/project_id",schemaPath:"#/properties/project_id/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.revision_id !== undefined){
let data2 = data.revision_id;
const _errs5 = errors;
if(errors === _errs5){
if(typeof data2 === "string"){
if(func1(data2) < 1){
validate20.errors = [{instancePath:instancePath+"/revision_id",schemaPath:"#/properties/revision_id/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
}
else {
validate20.errors = [{instancePath:instancePath+"/revision_id",schemaPath:"#/properties/revision_id/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.synced_at !== undefined){
let data3 = data.synced_at;
const _errs7 = errors;
if(errors === _errs7){
if(typeof data3 === "string"){
if(!pattern4.test(data3)){
validate20.errors = [{instancePath:instancePath+"/synced_at",schemaPath:"#/properties/synced_at/pattern",keyword:"pattern",params:{pattern: "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$"},message:"must match pattern \""+"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$"+"\""}];
return false;
}
}
else {
validate20.errors = [{instancePath:instancePath+"/synced_at",schemaPath:"#/properties/synced_at/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.modules !== undefined){
let data4 = data.modules;
const _errs9 = errors;
if(errors === _errs9){
if(Array.isArray(data4)){
var valid1 = true;
const len0 = data4.length;
for(let i0=0; i0<len0; i0++){
const _errs11 = errors;
if(!(validate21(data4[i0], {instancePath:instancePath+"/modules/" + i0,parentData:data4,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate21.errors : vErrors.concat(validate21.errors);
errors = vErrors.length;
}
var valid1 = _errs11 === errors;
if(!valid1){
break;
}
}
}
else {
validate20.errors = [{instancePath:instancePath+"/modules",schemaPath:"#/properties/modules/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
}
}
}
}
}
}
}
else {
validate20.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate20.errors = vErrors;
return errors === 0;
}
validate20.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};
