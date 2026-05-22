void modify_restir_gi(inout vec3 color){
    color = saturateColors(color, 1.2);
    color *= mix(0.45, 0.07, sunVisibility2);
}
