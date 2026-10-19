import * as THREE from './vendor/three.module.mjs';

// Crossfade two fully depth-tested renders, not translucent fabric triangles.
// This keeps folds, the back of the sheet and the eyes consistently occluded.
export function createFadeRenderer(renderer,scene,camera,companion){
 let full=null,eyes=null,material=null,screenScene=null,plane=null,screenCamera=null;
 function allocate(){
  if(full)return;
 const size=renderer.getDrawingBufferSize(new THREE.Vector2());
 const options={type:THREE.HalfFloatType,samples:Math.min(4,renderer.capabilities.maxSamples)};
 full=new THREE.WebGLRenderTarget(size.x,size.y,options);
 eyes=new THREE.WebGLRenderTarget(size.x,size.y,options);
 material=new THREE.ShaderMaterial({
  uniforms:{fullImage:{value:full.texture},eyesImage:{value:eyes.texture},visibility:{value:1}},
  vertexShader:`varying vec2 vUv;void main(){vUv=uv;gl_Position=vec4(position.xy,0.0,1.0);}`,
  fragmentShader:`
   uniform sampler2D fullImage;uniform sampler2D eyesImage;uniform float visibility;
   varying vec2 vUv;
   void main(){
    vec4 color=mix(texture2D(eyesImage,vUv),texture2D(fullImage,vUv),visibility);
    gl_FragColor=vec4(color.a>0.00001?color.rgb/color.a:vec3(0.0),color.a);
    #include <tonemapping_fragment>
    #include <colorspace_fragment>
    #include <premultiplied_alpha_fragment>
   }`,
  depthTest:false,depthWrite:false,premultipliedAlpha:true
 });
 screenScene=new THREE.Scene();
 plane=new THREE.Mesh(new THREE.PlaneGeometry(2,2),material);plane.frustumCulled=false;screenScene.add(plane);
 screenCamera=new THREE.Camera();
 }
 function release(){
  full?.dispose();eyes?.dispose();material?.dispose();plane?.geometry.dispose();
  full=eyes=material=screenScene=plane=screenCamera=null;
 }
 function render(){
  // Both paths use the renderer's same tone mapping/output colour space.
  // Opaque idle frames need no intermediate texture or full-screen resolve.
  if(companion.visibility===1){release();companion.sheet.visible=true;renderer.setRenderTarget(null);renderer.render(scene,camera);return}
  allocate();
  const previous=companion.sheet.visible;
  if(companion.visibility>0){companion.sheet.visible=true;renderer.setRenderTarget(full);renderer.render(scene,camera);}
  if(companion.visibility<1){companion.sheet.visible=false;renderer.setRenderTarget(eyes);renderer.render(scene,camera);}
  companion.sheet.visible=previous;
  material.uniforms.visibility.value=companion.visibility;
  renderer.setRenderTarget(null);renderer.render(screenScene,screenCamera);
 }
 function dispose(){release()}
 function resize(){if(!full)return;const pixels=renderer.getDrawingBufferSize(new THREE.Vector2());full.setSize(pixels.x,pixels.y);eyes.setSize(pixels.x,pixels.y)}
 return {render,dispose,resize,get allocatedBuffers(){return full?2:0}};
}
