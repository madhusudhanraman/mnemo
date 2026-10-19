// Keep the CPU surface in ghost.mjs as the reference for geometry tests and eye anchors.
// Only uniforms change per frame; the sheet's position/normal buffers stay static.
export const clothVertexSource=`
attribute vec2 clothParam;
uniform float clothTime;
uniform float clothSpeed;
uniform float clothFlutter;
uniform float clothPhase;
vec3 clothSurface(float theta,float v){
 v=clamp(v,0.0,1.0);
 float t=clothTime;
 float y=1.60-3.10*v;
 float dome=v<.34?sqrt(max(0.0,1.0-pow((y-.546)/1.054,2.0))):1.0;
 float flare=smoothstep(.34,1.0,v),drape=smoothstep(.20,1.0,v),free=v*v;
 float radius=1.04*dome+.26*flare;
 float folds=(cos(theta*7.0+.3*sin(theta*2.0))*.065+sin(theta*11.0-v*5.0+t*1.35*clothSpeed)*.031)*drape;
 float ripple=(sin(theta*4.0+v*6.0-t*1.55*clothSpeed)*.042+cos(theta*3.0-v*3.0+t*.83)*.027)*free;
 float r=radius+folds+ripple;
 float swayX=sin(t*.95-v*2.8)*.19*pow(v,1.8);
 float swayZ=cos(t*.71-v*2.1)*.10*v*v;
 float hem=(sin(theta*6.0+t*.70)*.11+sin(theta*3.0-t*1.15)*.075)*pow(v,7.0);
 float breath=sin(t*.85)*.009*dome;
 vec3 p=vec3(sin(theta)*(r+breath)+swayX,y+hem+sin(theta*2.0+t*.9)*.025*free,cos(theta)*(r+breath)*.82+swayZ);
 float loose=max(0.0,(v-.34)/.66),weight=loose*loose*clothFlutter;
 float wave=sin(theta*3.0-v*7.0-clothPhase*7.0);
 float angle=weight*(.62+.16*sin(v*7.0-clothPhase*5.0));
 float radial=1.0-weight*.13+weight*.075*wave;
 float c=cos(angle),s=sin(angle);
 return vec3((p.x*c+p.z*s)*radial,p.y+weight*(.10+.12*wave),(p.z*c-p.x*s)*radial);
}
vec3 clothNormal(float theta,float v){
 if(v<.0001)return vec3(0.0,1.0,0.0);
 vec3 tangent=clothSurface(theta+.001,v)-clothSurface(theta-.001,v);
 vec3 vertical=clothSurface(theta,v+.001)-clothSurface(theta,v-.001);
 vec3 n=cross(vertical,tangent);
 return dot(n,n)>.0000000001?normalize(n):vec3(0.0,1.0,0.0);
}
`;
export function installClothGPU(material){
 const uniforms={clothTime:{value:0},clothSpeed:{value:1},clothFlutter:{value:0},clothPhase:{value:0}};
 material.onBeforeCompile=shader=>{
  Object.assign(shader.uniforms,uniforms);
  shader.vertexShader=clothVertexSource+shader.vertexShader;
  shader.vertexShader=shader.vertexShader.replace('#include <beginnormal_vertex>',`vec3 objectNormal=clothNormal(clothParam.x,clothParam.y);
#ifdef USE_TANGENT
vec3 objectTangent=vec3(tangent.xyz);
#endif`);
  shader.vertexShader=shader.vertexShader.replace('#include <begin_vertex>','vec3 transformed=clothSurface(clothParam.x,clothParam.y);');
 };
 material.customProgramCacheKey=()=> 'mnemo-cloth-gpu-v1';
 return uniforms;
}
