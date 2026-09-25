import Foundation

/// Metal source for the display stage.
///
/// The Command Line Tools do not ship the offline Metal compiler, so this is
/// compiled at launch with `makeLibrary(source:)`.
///
/// Independent Metal implementation informed by CRT Guest Advanced HD:
/// https://github.com/libretro/slang-shaders/tree/master/crt/shaders/guest/hd
/// Uses sharp reconstruction, brightness-dependent beams, and separate glow.
/// No upstream shader code is copied.
///
/// This reconstructs a picture tube rather than drawing lines over the image.
/// Each output pixel asks which scan lines light it and by how much, using a
/// beam profile whose width grows with brightness. All of it happens in linear
/// light, which is why bright areas bleed and dark areas stay tight.
enum CRTShaders {
  static let source = """
  #include <metal_stdlib>
  using namespace metal;

  struct Uniforms {
      float2 sourceSize;      // pixels in the game image
      float2 outputSize;      // pixels on screen
      float  curvature;       // 0 flat, higher is flatter barrel
      float  curvatureY;      // vertical barrel strength
      float  cornerRadius;    // rounded glass corner radius in UV space
      float  cornerSoftness;  // rounded glass corner transition in UV space
      float  scanlineDepth;   // 0 none, 1 full
      float  beamWidth;       // scan line beam sigma, in source lines
      float  beamBloom;       // how much brightness widens the beam
      float  maskStrength;    // phosphor mask depth
      float  maskType;        // 0 aperture grille, 1 shadow mask
      float  maskSize;        // phosphor pitch in output pixels
      float  maskDark;        // dark phosphor multiplier
      float  maskLight;       // lit phosphor multiplier
      float  bloomAmount;     // halation added back
      float  gamma;           // tube gamma
      float  brightness;
      float  brightBoostDark; // gain applied to dark source colours
      float  brightBoostBright; // gain applied to bright source colours
      float  saturation;
      float  convergence;     // colour misalignment, in output pixels
      float  convergenceY;    // vertical colour misalignment, in output pixels
      float  vignette;
      float  pixelAspect;     // horizontal stretch, PAL is not square
      float  colorLevels;     // 0 keeps full depth, 16 is Amiga OCS
      float  hdrHeadroom;     // display-relative peak, capped at 8x SDR white
  };

  struct VOut {
      float4 position [[position]];
      float2 uv;
  };

  vertex VOut crt_vertex(uint vid [[vertex_id]]) {
      float2 quad[4] = { float2(-1,-1), float2(1,-1), float2(-1,1), float2(1,1) };
      VOut out;
      out.position = float4(quad[vid], 0.0, 1.0);
      // Flip vertically: image rows run top down, clip space runs bottom up.
      out.uv = float2(quad[vid].x * 0.5 + 0.5, 0.5 - quad[vid].y * 0.5);
      return out;
  }

  static inline float3 toLinear(float3 c, float g) { return pow(max(c, 0.0), g); }
  static inline float3 toGamma(float3 c, float g) { return pow(max(c, 0.0), 1.0 / g); }

  // Barrel distortion, as the glass of a real tube bends the image.
  static inline float2 curveUV(float2 uv, float amountX, float amountY) {
      if (amountX <= 0.0 && amountY <= 0.0) { return uv; }
      float2 c = uv * 2.0 - 1.0;
      float2 original = c;
      c.x += original.x * pow(abs(original.y) / max(amountX, 0.0001), 2.0);
      c.y += original.y * pow(abs(original.x) / max(amountY, 0.0001), 2.0);
      return c * 0.5 + 0.5;
  }

  static inline float cornerMask(float2 uv, float radius, float softness) {
      if (radius <= 0.0) { return 1.0; }
      float2 edge = min(uv, 1.0 - uv);
      float2 outside = max(radius - edge, 0.0);
      float distance = length(outside);
      return 1.0 - smoothstep(radius - max(softness, 0.0001), radius, distance);
  }

  // Gaussian beam. Brighter lines spread wider, which is the halation that
  // makes highlights glow on a tube.
  static inline float beamWeight(float distance, float sigma, float luma, float bloom) {
      float widened = sigma * (1.0 + bloom * luma);
      float x = distance / max(widened, 0.0001);
      return exp(-0.5 * x * x);
  }

  // ---- Bloom passes -------------------------------------------------------

  fragment float4 crt_bright(
      VOut in [[stage_in]],
      texture2d<float> src [[texture(0)]],
      constant Uniforms &u [[buffer(0)]]
  ) {
      constexpr sampler smp(filter::linear, address::clamp_to_edge);
      float3 c = toLinear(src.sample(smp, in.uv).rgb, u.gamma);
      float luma = dot(c, float3(0.299, 0.587, 0.114));
      // Keep only the part above mid level, which is what scatters in glass.
      float excess = max(luma - 0.35, 0.0) / 0.65;
      return float4(c * excess, 1.0);
  }

  fragment float4 crt_blur_h(
      VOut in [[stage_in]],
      texture2d<float> src [[texture(0)]],
      constant Uniforms &u [[buffer(0)]]
  ) {
      constexpr sampler smp(filter::linear, address::clamp_to_edge);
      float2 step = float2(1.0 / u.sourceSize.x, 0.0);
      float weights[5] = { 0.227, 0.194, 0.121, 0.054, 0.016 };
      float3 sum = src.sample(smp, in.uv).rgb * weights[0];
      for (int i = 1; i < 5; ++i) {
          float o = float(i) * 1.5;
          sum += src.sample(smp, in.uv + step * o).rgb * weights[i];
          sum += src.sample(smp, in.uv - step * o).rgb * weights[i];
      }
      return float4(sum, 1.0);
  }

  fragment float4 crt_blur_v(
      VOut in [[stage_in]],
      texture2d<float> src [[texture(0)]],
      constant Uniforms &u [[buffer(0)]]
  ) {
      constexpr sampler smp(filter::linear, address::clamp_to_edge);
      float2 step = float2(0.0, 1.0 / u.sourceSize.y);
      float weights[5] = { 0.227, 0.194, 0.121, 0.054, 0.016 };
      float3 sum = src.sample(smp, in.uv).rgb * weights[0];
      for (int i = 1; i < 5; ++i) {
          float o = float(i) * 1.5;
          sum += src.sample(smp, in.uv + step * o).rgb * weights[i];
          sum += src.sample(smp, in.uv - step * o).rgb * weights[i];
      }
      return float4(sum, 1.0);
  }

  // ---- Composite ----------------------------------------------------------

  fragment float4 crt_composite(
      VOut in [[stage_in]],
      texture2d<float> src [[texture(0)]],
      texture2d<float> bloom [[texture(1)]],
      texture2d<float> flash [[texture(2)]],
      constant Uniforms &u [[buffer(0)]]
  ) {
      constexpr sampler smp(filter::linear, address::clamp_to_edge);
      float2 uv = curveUV(in.uv, u.curvature, u.curvatureY);

      // Outside the glass there is no picture.
      if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
          return float4(0.0, 0.0, 0.0, 1.0);
      }

      // Which source scan line are we between?
      float linePos = uv.y * u.sourceSize.y - 0.5;
      float baseLine = floor(linePos);
      float frac = linePos - baseLine;

      // Limited video bandwidth softens horizontally, not vertically.
      float2 texel = 1.0 / u.sourceSize;
      float3 accumulated = float3(0.0);
      float weightSum = 0.0;

      // Gather the neighbouring scan lines and weight each by the beam.
      for (int i = -1; i <= 2; ++i) {
          float line = baseLine + float(i);
          float2 sampleUV = float2(uv.x, (line + 0.5) * texel.y);

          // Limit interpolation to the output pixel footprint. This preserves
          // single-pixel lettering without a sharpen filter's ringing.
          float x = sampleUV.x * u.sourceSize.x;
          float footprint = min(1.0, u.sourceSize.x / u.outputSize.x);
          float phase = (fract(x) - 0.5) / max(footprint, 0.0001);
          sampleUV.x = (floor(x) + 0.5 + clamp(phase, -0.5, 0.5)) * texel.x;
          float3 c = toLinear(src.sample(smp, sampleUV).rgb, u.gamma);

          float luma = dot(c, float3(0.299, 0.587, 0.114));
          float w = beamWeight(float(i) - frac, u.beamWidth, luma, u.beamBloom);
          accumulated += c * w;
          weightSum += w;
      }

      float3 color = weightSum > 0.0 ? accumulated / weightSum : float3(0.0);

      // Reduce colour depth before the tube, as a machine with a shallower
      // palette would have fed it. OCS and ECS held four bits per channel.
      if (u.colorLevels > 1.0) {
          float steps = u.colorLevels - 1.0;
          float3 display = toGamma(color, u.gamma);
          display = round(display * steps) / steps;
          color = toLinear(display, u.gamma);
      }

      // Source-aligned scanlines fade out when the display cannot resolve
      // them. Integrate the cosine over a pixel to avoid moire on resizing.
      float lineFootprint = max(fwidth(linePos), 0.0001);
      float resolved = smoothstep(1.25, 2.5, 1.0 / lineFootprint);
      float phaseWidth = min(lineFootprint, 1.0) * M_PI_F;
      float attenuation = sin(phaseWidth) / phaseWidth;
      float gap = 0.5 - 0.5 * cos(2.0 * M_PI_F * linePos) * attenuation;
      color *= 1.0 - u.scanlineDepth * resolved * gap;

      // Phosphor mask. The tube lights red, green and blue stripes or dots,
      // so full white is never one flat colour.
      float3 mask = float3(1.0);
      float pitch = max(u.maskSize, 0.5);
      float px = floor(in.uv.x * u.outputSize.x / pitch);
      float py = floor(in.uv.y * u.outputSize.y / pitch);
      if (u.maskType < 0.5) {
          // Aperture grille: vertical RGB stripes.
          int phase = int(fmod(px, 3.0));
          mask = float3(phase == 0 ? u.maskLight : u.maskDark,
                       phase == 1 ? u.maskLight : u.maskDark,
                       phase == 2 ? u.maskLight : u.maskDark);
      } else {
          // Shadow mask: the dots stagger every other row.
          float rowShift = fmod(py, 2.0) * 1.5;
          int phase = int(fmod(px + rowShift, 3.0));
          mask = float3(phase == 0 ? u.maskLight : u.maskDark,
                       phase == 1 ? u.maskLight : u.maskDark,
                       phase == 2 ? u.maskLight : u.maskDark);
      }
      color *= mix(float3(1.0), mask, u.maskStrength * resolved);

      // Convergence: the three guns never align perfectly.
      if (u.convergence > 0.0 || u.convergenceY > 0.0) {
          float2 shift = float2(u.convergence / u.outputSize.x,
                                u.convergenceY / u.outputSize.y);
          float r = toLinear(src.sample(smp, uv + shift).rgb, u.gamma).r;
          float b = toLinear(src.sample(smp, uv - shift).rgb, u.gamma).b;
          color.r = mix(color.r, r * mask.r, 0.35);
          color.b = mix(color.b, b * mask.b, 0.35);
      }

      // Halation from the bloom passes.
      float3 glow = bloom.sample(smp, uv).rgb;
      color += glow * u.bloomAmount;

      // Brightness-dependent gain and saturation match the limited drive of a
      // consumer tube without flattening the source palette.
      float peak = max(max(color.r, color.g), color.b);
      color *= mix(u.brightBoostDark, u.brightBoostBright, clamp(peak, 0.0, 1.0));
      float luma = dot(color, float3(0.4, 0.5, 0.1));
      color = mix(float3(luma), color, u.saturation);

      // The mask eats light, so put some back.
      color *= u.brightness;

      // Vignette, from the shadow of the tube edge.
      if (u.vignette > 0.0) {
          float2 c = in.uv * 2.0 - 1.0;
          float falloff = 1.0 - u.vignette * dot(c, c) * 0.25;
          color *= clamp(falloff, 0.0, 1.0);
      }
      color *= cornerMask(uv, u.cornerRadius, u.cornerSoftness);

      // Preserve the old SDR appearance in an extended-linear sRGB drawable.
      // The previous UNorm target clipped these encoded values at SDR white.
      float3 encoded = clamp(toGamma(color, u.gamma),0.0,1.0);
      color = select(pow((encoded+.055)/1.055,float3(2.4)), encoded/12.92, encoded <= .04045);
      constexpr sampler nearest(filter::nearest,address::clamp_to_zero);
      float strength = flash.sample(nearest,uv).r;
      if (strength > 0 && u.hdrHeadroom > 1) {
          float3 tint = strength > .75 ? float3(1) : float3(1,1,0);
          color = tint * (1 + (u.hdrHeadroom-1)*strength);
      }
      float green = flash.sample(nearest,uv).g;
      if (green > 0 && u.hdrHeadroom > 1) {
          color = float3(.18,1,.18) * (1 + (u.hdrHeadroom-1)*green);
      }
      return float4(color, 1.0);
  }
  """
}
