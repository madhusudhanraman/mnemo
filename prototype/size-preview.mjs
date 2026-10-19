import * as THREE from './vendor/three.module.mjs';

export function clothScreenBounds(companion,camera,viewportHeight){
 companion.group.updateMatrixWorld(true);camera.updateMatrixWorld(true);
 const positions=companion.geometry.attributes.position,p=new THREE.Vector3();
 let top=Infinity,bottom=-Infinity;
 for(let i=0;i<positions.count;i++){
  p.fromBufferAttribute(positions,i).applyMatrix4(companion.sheet.matrixWorld).project(camera);
  const y=(1-p.y)*.5*viewportHeight;top=Math.min(top,y);bottom=Math.max(bottom,y);
 }
 return {top,bottom,height:bottom-top};
}

export function fitGhostHeight(companion,camera,targetHeight,viewportHeight,baseline){
 for(let pass=0;pass<16;pass++){
  let bounds=clothScreenBounds(companion,camera,viewportHeight);
  companion.group.scale.multiplyScalar(targetHeight/bounds.height);
  bounds=clothScreenBounds(companion,camera,viewportHeight);
  companion.group.position.y+=(bounds.bottom-baseline)*(20*Math.tan(THREE.MathUtils.degToRad(camera.fov/2))/viewportHeight);
 }
 return clothScreenBounds(companion,camera,viewportHeight);
}
