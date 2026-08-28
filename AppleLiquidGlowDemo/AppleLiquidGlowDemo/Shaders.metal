#include <metal_stdlib>
using namespace metal;

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float noise2(float2 p) {
    float2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i), b = hash21(i + float2(1, 0));
    float c = hash21(i + float2(0, 1)), d = hash21(i + float2(1, 1));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

static float fbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; ++i) {
        v += noise2(p) * a;
        p = p * 2.03 + float2(17.1, 9.2);
        a *= 0.5;
    }
    return v;
}

/// A Gaussian-blurred thin ring of radius `R` and blur `s`, evaluated at radius
/// `r`: exp(-(r²+R²)/2s²)·I₀(rR/s²).
///
/// This is the whole idle-to-droplet transition in one function. Measuring the
/// reference showed the idle haze is not a separate cloud at all — it is this
/// very ring (R came out at 110px against the crisp bubble's 108px) under a
/// blur of about 100px. Shrinking `s` resolves the haze into the bubble, and
/// the apparent shrink is entirely the blur letting go.
static float blurredRing(float r, float R, float s) {
    float s2 = max(s * s, 1e-6);
    float z = r * R / s2;
    float A = (r * r + R * R) / (2.0 * s2);

    if (z < 3.75) {
        float t = z / 3.75; t *= t;
        float i0 = 1.0 + t * (3.5156229 + t * (3.0899424 + t * (1.2067492 +
                   t * (0.2659732 + t * (0.0360768 + t * 0.0045813)))));
        return exp(-A) * i0;
    }
    // Fold I₀'s growing exponential into the envelope: z - A = -(r-R)²/2s².
    float t = 3.75 / z;
    float poly = 0.39894228 + t * (0.01328592 + t * (0.00225319 + t * (-0.00157565 +
                 t * (0.00916281 + t * (-0.02057706 + t * (0.02635537 +
                 t * (-0.01647633 + t * 0.00392377)))))));
    return exp(z - A) * poly / sqrt(z);
}

static float sdRoundBox(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

/// The CSS "animated border-radius" droplet: four quarter-ellipses that meet
/// exactly on the axes, each with its own slowly drifting radius. Low order and
/// perfectly smooth — the blob bulges and rolls instead of rippling.
static float sdDroplet(float2 p, float radius, float t, float life) {
    // Small amplitude, but the *direction* of the bulge has to read clearly, so
    // the four radii run on well-separated slow periods and stay out of phase
    // instead of averaging into a uniform pulse.
    // The reference bubble stays close to round — 230x210px, aspect 1.10.
    float amp = 0.095 * life;

    float aL = amp * sin(t * 0.92);
    float aR = amp * sin(t * 0.74 + 2.6);
    float aT = amp * sin(t * 0.65 + 4.4);
    float aB = amp * sin(t * 0.83 + 1.2);

    // Keep the enclosed area roughly constant while the radii trade off.
    float norm = 1.0 / (1.0 + (aL + aR + aT + aB) * 0.25);

    // Blend the radii across the axes rather than switching hard: a hard switch
    // leaves a gradient kink that shows up as a cross seam once the distance
    // field drives any shading.
    float w = radius * 0.55;
    float rx = radius * (1.0 + mix(aL, aR, smoothstep(-w, w, p.x))) * norm;
    float ry = radius * (1.0 + mix(aT, aB, smoothstep(-w, w, p.y))) * norm;

    float2 v = p / max(float2(rx, ry), 1e-4);
    float base = (length(v) - 1.0) * min(rx, ry);

    // On top of the slow roll, a bulge that crawls around the perimeter. The
    // four-axis term alone only ever breathes in place; this is what makes the
    // outline look like it is being pushed round from the inside.
    float th = atan2(p.y, p.x);
    float crawl = 0.030 * sin(2.0 * th - t * 1.9)
                + 0.020 * sin(3.0 * th + t * 1.35 + 1.7);
    return base - crawl * radius * life;
}

/// Stand-in for the generated artwork. Theme 0 is the reference GIF's Starry
/// Night; 1–5 follow the suggestion chips along the bottom.
///
/// `detail` scales everything with structure in it. Outside the outline the
/// coordinate is folded back onto the edge, so a star there would smear down
/// the whole ray as a radial streak; dropping detail to zero leaves just the
/// smooth sky ramp, which is exactly what the coloured shadow wants.
static float3 artworkColor(float2 uv, float t, float detail, float theme) {
    float h = uv.y * 0.5 + 0.5;                      // 0 top, 1 bottom
    int k = int(theme + 0.5);
    const float horizon = (k == 4) ? 0.62 : 0.75;

    float3 sky;
    if (k == 1) {
        // Brian — warm portrait: skin, dark hair, soft studio falloff.
        sky = mix(float3(0.18, 0.12, 0.10), float3(0.42, 0.28, 0.22), smoothstep(0.00, 0.28, h));
        sky = mix(sky, float3(0.78, 0.55, 0.44), smoothstep(0.22, 0.48, h));
        sky = mix(sky, float3(0.92, 0.72, 0.60), smoothstep(0.42, 0.64, h));
        sky = mix(sky, float3(0.55, 0.32, 0.24), smoothstep(0.60, 0.82, h));
        sky = mix(sky, float3(0.22, 0.12, 0.10), smoothstep(0.78, 1.00, h));
    } else if (k == 2) {
        // Mage — deep violet, magenta core, gold runes along the bottom.
        sky = mix(float3(0.06, 0.04, 0.16), float3(0.22, 0.08, 0.42), smoothstep(0.00, 0.30, h));
        sky = mix(sky, float3(0.62, 0.18, 0.72), smoothstep(0.24, 0.52, h));
        sky = mix(sky, float3(0.95, 0.48, 0.82), smoothstep(0.48, 0.68, h));
        sky = mix(sky, float3(0.98, 0.78, 0.42), smoothstep(0.64, 0.82, h));
        sky = mix(sky, float3(0.18, 0.08, 0.28), smoothstep(0.80, 1.00, h));
    } else if (k == 3) {
        // Artist — paint-splashed studio, cadmium and teal.
        sky = mix(float3(0.12, 0.16, 0.22), float3(0.20, 0.45, 0.62), smoothstep(0.00, 0.28, h));
        sky = mix(sky, float3(0.95, 0.42, 0.22), smoothstep(0.22, 0.50, h));
        sky = mix(sky, float3(0.98, 0.82, 0.28), smoothstep(0.46, 0.66, h));
        sky = mix(sky, float3(0.28, 0.72, 0.58), smoothstep(0.62, 0.82, h));
        sky = mix(sky, float3(0.16, 0.12, 0.10), smoothstep(0.80, 1.00, h));
    } else if (k == 4) {
        // Baseball cap — noon sky over a grass field.
        sky = mix(float3(0.35, 0.62, 0.95), float3(0.62, 0.82, 0.98), smoothstep(0.00, 0.40, h));
        sky = mix(sky, float3(0.95, 0.95, 0.92), smoothstep(0.38, horizon, h));
        sky = mix(sky, float3(0.28, 0.62, 0.22), smoothstep(horizon, 0.78, h));
        sky = mix(sky, float3(0.16, 0.38, 0.14), smoothstep(0.76, 1.00, h));
    } else if (k == 5) {
        // Helmet — carbon and racing red, a bright visor slash.
        sky = mix(float3(0.08, 0.08, 0.10), float3(0.22, 0.18, 0.20), smoothstep(0.00, 0.30, h));
        sky = mix(sky, float3(0.82, 0.12, 0.14), smoothstep(0.24, 0.52, h));
        sky = mix(sky, float3(0.95, 0.55, 0.22), smoothstep(0.48, 0.68, h));
        sky = mix(sky, float3(0.55, 0.58, 0.62), smoothstep(0.64, 0.84, h));
        sky = mix(sky, float3(0.10, 0.10, 0.12), smoothstep(0.82, 1.00, h));
    } else {
        // Starry Night — sampled off the reference card.
        sky = mix(float3(0.13, 0.18, 0.40), float3(0.17, 0.29, 0.62),
                  smoothstep(0.00, 0.32, h));
        sky = mix(sky, float3(0.50, 0.36, 0.66), smoothstep(0.24, 0.54, h));
        sky = mix(sky, float3(0.94, 0.62, 0.88), smoothstep(0.50, 0.68, h));
        sky = mix(sky, float3(0.96, 0.92, 0.94), smoothstep(0.64, horizon, h));
        sky = mix(sky, float3(0.95, 0.84, 0.66), smoothstep(horizon, 0.84, h));
        sky = mix(sky, float3(0.72, 0.52, 0.62), smoothstep(0.82, 0.93, h));
        sky = mix(sky, float3(0.24, 0.26, 0.42), smoothstep(0.91, 1.00, h));
    }

    // A concentrated light (sun, visor glint, studio lamp) sitting on the
    // horizon. Portrait and racing themes keep it off-centre so they do not
    // read as the same sunset as Starry Night.
    float2 lamp = (k == 1) ? float2(-0.22, 0.18)
                : (k == 5) ? float2(0.28, -0.10)
                : float2(0.0, (horizon - 0.5) * 2.0);
    float centred = 0.52 + 0.48 * exp(-uv.x * uv.x * 1.4);
    sky *= mix(1.0, centred, (k == 0 || k == 4) ? smoothstep(0.58, 0.70, h) : 0.35);

    float2 ds = uv - lamp;
    sky += float3(1.00, 0.90, 0.68) * exp(-dot(ds, ds) * 420.0) * 0.55 * detail;
    sky += float3(1.00, 0.74, 0.46) * exp(-dot(ds, ds) * 50.0) * 0.18;

    // Stars belong to the night themes. Two grids at different densities so
    // they do not look tiled.
    if (k == 0 || k == 2) {
        for (int i = 0; i < 2; ++i) {
            float scale = (i == 0) ? 26.0 : 41.0;
            float2 cell = uv * scale + float(i) * 11.3;
            float rnd = hash21(floor(cell));
            float2 c = fract(cell) - 0.5;
            float star = exp(-dot(c, c) * 110.0)
                       * step(0.88, rnd)
                       * smoothstep(0.68, 0.05, h)
                       * (0.5 + 0.5 * sin(t * 2.6 + rnd * 40.0));
            sky += star * (i == 0 ? 2.6 : 1.5) * detail;
        }
    }

    float cl = fbm(uv * 2.6 + float2(t * 0.025, 0.0));
    float3 cloudCol = (k == 4) ? float3(0.96, 0.96, 0.98)
                    : (k == 3) ? float3(0.98, 0.62, 0.28)
                    : (k == 1) ? float3(0.62, 0.42, 0.32)
                    : float3(0.86, 0.56, 0.74);
    sky = mix(sky, cloudCol,
              smoothstep(0.48, horizon, h) * smoothstep(0.38, 0.66, cl) * 0.55 * detail);

    return sky;
}

/// The ring's colour by angle, resampled off frame 42 after refitting the
/// centre. Every earlier version of this was taken about (305,302) with R=127px
/// when the real fit is (322,297) with R=156px, so the whole wheel was sampled
/// off-centre and came out with no warm side at all. There is in fact a strong
/// orange arc (hue 7-9, saturation 0.62) sweeping the bottom and lower right,
/// a near-white highlight at the upper right, and periwinkle up the left flank.
/// Where on a 12-spoke colour table an angle lands, with a smoothed fraction.
/// Lobe fitting is not usable here: fitting `pow(cos, k)` lobes to anchors and
/// normalising averages three or four of them at every angle, which drags the
/// output toward grey. Measured saturation of that scheme was 0.20 mean against
/// the reference's 0.65 — the palette has to be interpolated, not blended.
static void wheelIndex(float a, thread int &i0, thread int &i1, thread float &f) {
    float x = a * (6.0 / 3.14159265);
    x = x - floor(x / 12.0) * 12.0;
    i0 = int(x);
    i1 = (i0 + 1) % 12;
    f = x - float(i0);
    f = f * f * (3.0 - 2.0 * f);
}

/// The rim's actual colour, sampled at each ray's *chroma* peak rather than its
/// luminance peak. Those are not the same radius: the brightest pixel on the
/// left flank is a washed-out (161,156,208) at 76pt, while 5pt further in sits
/// a vivid (75,157,213) cyan. Anchoring on brightness picks the pale one every
/// time, which is exactly why the old rim was grey.
static float3 vividWheel(float a) {
    const float3 C[12] = {
        float3(0.455, 0.325, 0.482),   //    0  plum
        float3(0.624, 0.349, 0.282),   //   30  rust
        float3(0.608, 0.345, 0.282),   //   60
        float3(0.647, 0.373, 0.298),   //   90  straight down
        float3(0.612, 0.353, 0.294),   //  120
        float3(0.341, 0.400, 0.545),   //  150  turning cool
        float3(0.294, 0.616, 0.835),   //  180  left, vivid cyan
        float3(0.286, 0.635, 0.863),   //  210
        float3(0.275, 0.596, 0.816),   //  240
        float3(0.451, 0.506, 0.675),   //  270  muted blue
        float3(0.447, 0.341, 0.482),   //  300
        float3(0.443, 0.329, 0.482)    //  330
    };
    int i0, i1; float f;
    wheelIndex(a, i0, i1, f);
    return mix(C[i0], C[i1], f);
}

/// The pale highlight riding just outside the vivid band — brighter but almost
/// colourless. This is the layer the old palette captured, and on its own it is
/// the entire "muddy" problem: it is the specular, not the material.
static float3 paleWheel(float a) {
    const float3 C[12] = {
        float3(0.694, 0.533, 0.616),
        float3(0.855, 0.639, 0.624),
        float3(0.898, 0.643, 0.584),
        float3(0.863, 0.620, 0.584),
        float3(0.745, 0.502, 0.518),
        float3(0.631, 0.490, 0.647),
        float3(0.631, 0.612, 0.816),
        float3(0.663, 0.624, 0.835),
        float3(0.635, 0.604, 0.835),
        float3(0.451, 0.506, 0.675),
        float3(0.455, 0.357, 0.494),
        float3(0.678, 0.659, 0.867)
    };
    int i0, i1; float f;
    wheelIndex(a, i0, i1, f);
    return mix(C[i0], C[i1], f);
}

/// Stage-driven, not free-running. `phase` is stepped by the UI, and the timing
/// mirrors the reference GIF (10fps, frame numbers in brackets):
///   0.00  idle    breathing haze — the droplet's own ring, blurred  [1-35]
///   0.45  droplet it contracts inward and resolves, Ø167pt          [36-55]
///   0.62  texture artwork fills the droplet                         [56-70]
///   1.00  card    fast inflate into a 266pt squircle                [71-91]
[[ stitchable ]] half4 applePlaygroundFlow(
    float2 position,
    half4 inputColor,
    float2 size,
    float time,
    float phase,
    float theme
) {
    float2 p = (position - size * 0.5) / max(min(size.x, size.y), 1.0);

    float t = time;

    // `sharpen` is the blur letting go: 0 is the idle haze, 1 the crisp bubble.
    // Everything downstream is one object — there is no separate cloud layer.
    float sharpen = smoothstep(0.04, 0.44, phase);
    float artAmt  = smoothstep(0.50, 0.66, phase);
    float morph   = smoothstep(0.74, 0.96, phase);
    morph = morph * morph * (3.0 - 2.0 * morph);

    // Idle breathing, refit off the 60fps capture (12fps sampling): the radius
    // runs 88↔107px on an 800px crop as TWO superposed modes — a fast tremor
    // at ~0.55s (±6%) riding a slow swell at ~2.3s (±8%). The old single
    // 8.4s term read as a slow drift, not breathing.
    float breathe = 1.0
        + 0.060 * sin(t * 11.4) * (0.35 + 0.65 * (1.0 - sharpen))  // tremor damps, never fully
        + 0.080 * sin(t * 2.7 + 1.1);                               // slow swell
    p /= breathe;

    // The droplet is alive throughout; it only stiffens as it squares off.
    float life = 1.0 - 0.55 * morph;

    // ---- shape ------------------------------------------------------------
    // Refitting the droplet's centre moved its radius too: 102pt at frame 42
    // creeping to 106pt by frame 55, against the 83.5pt I had been using. Call
    // it Ø190, so R = 0.198 on the 480pt canvas, and the card 266pt.
    // The idle ring is smaller than the droplet, not bigger — fitting the
    // blurred ring to frame 34 gives R = 68pt. The haze looks broader purely
    // because of the blur, so as the blur lets go the whole thing visibly draws
    // inward even while the ring itself grows.
    // 0.198 put the outline at 95pt, which pushed the chroma band out to 88pt
    // against the reference's 72. The band is anchored at 0.86 of the radius,
    // so the outline has to sit at 84pt for it to land right.
    float ringR = mix(0.142, 0.175, sharpen);

    // Mid-contraction the reference drops to about 55% brightness before the
    // droplet resolves brighter than the haze ever was. Brightness only — the
    // radius has to stay monotonic. Undershooting it and easing back reads as
    // the droplet springing open again once it has already arrived.
    float condense = exp(-pow((sharpen - 0.55) / 0.28, 2.0));

    // Trigger flash: the capture's centre luminance jumps 13→158 within 0.25s
    // of the tap and decays over ~0.4s — generation *announces* itself before
    // the contraction. A transition that only ever dims reads as a crossfade.
    float flash = exp(-pow((sharpen - 0.22) / 0.17, 2.0));

    // Springy inflate: the capture overshoots radius +41% in ~0.1s and settles
    // +25% net when the sphere swells; the GIF's card snap runs 0.35s. A plain
    // smoothstep reads as a crossfade — this is the bounce.
    //
    // A damped sine cannot produce it: the first crest lands at morph≈0.28,
    // where the squircle is only 20% of the way to its resting size, so the
    // peak stays *below* the settle (0.238 vs 0.270) and reads as a slow-down,
    // not an overshoot. The measured bounce instead fires late — past the
    // resting size by +13% (133px against 118px) — then eases back. A Gaussian
    // bump centred near the end of the snap does exactly that: +22% at
    // morph 0.78 lifts the radius to 0.312 against the 0.277 settle, and
    // exp(-(0.22/0.13)²) has already decayed to +1% by morph 1.
    float infl = 1.0 + 0.22 * exp(-pow((morph - 0.78) / 0.13, 2.0));
    p /= infl;

    float S = mix(ringR, 0.277, morph) * infl;
    float droplet = sdDroplet(p, ringR, t, life);
    float square  = sdRoundBox(p, float2(0.277), mix(0.145, 0.070, morph));

    float d = mix(droplet, square, morph);

    // Artwork owns the interior and the outline; rim colour is only allowed
    // *outside*. A window that turns on at the outline (the old edgeOnly)
    // replaces the picture with ringLit on a 8pt band, which is a drawn
    // frame. The reference has no such line — the picture meets the glow.
    float outer = smoothstep(-0.025, 0.090, d / mix(ringR, 0.277, morph));

    float r  = length(p);
    float Rl = max(r - d, 1e-4);          // local outline radius, any SDF
    float u  = r / Rl;                    // 1 exactly on the outline

    // ---- radial layout ------------------------------------------------------
    // Brightness does not peak on the outline — measuring frame 44 along the
    // upper-left ray puts the maximum at 0.945 of the radius, with the visible
    // "edge" being that ring's outer slope. The card's peak sits closer in at
    // 0.985, which is why it reads as a hard-edged card and the droplet soft.
    float uPeak = mix(0.945, 0.985, morph);

    // The flat dark core runs much deeper than 0.30: profiling three rays puts
    // it at 0.55 of the peak radius before anything starts climbing, and the
    // climb is then near enough linear (fitted exponents 1.0, 1.06, 1.35).
    // Starting at 0.30 with a curve floods the interior with dim rim colour and
    // leaves a soft lens edge around the core instead of a clean dark centre.
    float i0 = mix(0.520, 0.660, morph);

    // Inward: flat fill, then a power climb to the ring. Fitted per shape — the
    // droplet's band is two thirds of its radius deep, the card's only a third.
    // The ring's centre sits left and low of the shape's, so the band piles up
    // thick along the left flank (peak at 0.96 there against 0.79 up-right).
    float uIn = length(p - float2(-0.071, 0.071) * S) / Rl;
    float inset = pow(clamp((uIn - i0) / (uPeak - i0), 0.0, 1.0), mix(1.15, 2.09, morph));

    // Outward: a tight core shadow riding on a wide ambient one. A single
    // exponential cannot do both — it either smears the edge or kills the halo.
    //
    // Driven off the signed distance rather than off `u`. Outside a
    // non-circular shape `Rl = r - d` grows with r, so u flattens instead of
    // climbing and the shadow never finishes decaying: measured 171/255 at
    // 96pt where the reference is 55. Inside the shape u is well behaved;
    // outside it, it is simply not a distance.
    float delta = max(d / S - (uPeak - 1.0) - 0.0, 0.0);
    float wA = mix(0.72, 0.80, morph);
    float kA = mix(0.090, 0.045, morph);
    float kB = mix(0.420, 0.300, morph);
    float covSharp = min(1.0, wA * exp(-delta / kA) + (1.0 - wA) * exp(-delta / kB));

    // Same ring with the blur still on it: sigma 36pt at idle, gone by the time
    // the droplet resolves. Normalise on the ring's own peak — normalising on
    // the centre blows up as sigma shrinks, because the centre value decays
    // like exp(-R^2/2s^2), and everything then clamps to a flat disc.
    float sigma = mix(0.38, 0.05, pow(sharpen, 0.6)) * Rl;
    float covBlur = blurredRing(r, Rl, sigma) / max(blurredRing(Rl, Rl, sigma), 1e-6);

    float alpha = mix(clamp(covBlur * 0.87, 0.0, 1.0), covSharp, sharpen);
    // Frame 1 is a compact orb on black, not a wash that reaches the canvas
    // corners. The blurred ring on its own keeps spilling once sigma is large.
    alpha *= mix(1.0 - smoothstep(0.26, 0.38, length(p)), 1.0, sharpen);

    // Without this the change reads as a crossfade instead of something pulling
    // itself together.
    alpha *= 1.0 - 0.42 * condense;

    // ---- colour ------------------------------------------------------------
    float ang = atan2(p.y, p.x);
    float ringVar = 0.96 + 0.10 * fbm(float2(cos(ang), sin(ang)) * 1.6 + t * 0.22);

    // The wheel rocks about its measured orientation rather than spinning. The
    // capture rocks the bright-mass centroid ±8° on a ~4.5s period (measured
    // −59°→−50°→−66°); the old 0.09 rad/s term never completed a single rock.
    float aw = ang + 0.15 * sin(t * 1.4);

    // ---- iridescence travelling outward -------------------------------------
    // Cross-correlating the *chroma* profile between consecutive frames gives
    // +22 pt/s outward on the droplet and +8.9 pt/s on the card, both decaying
    // to a stop about a second and a half after their transition. Correlating
    // luminance instead reports the card as static — the card's brightness
    // really does sit still, and only its colour travels. That measurement is
    // why the card used to get no wave at all.
    float waveSpeed = mix(0.73, 0.30, morph);        // x 30pt wavelength = pt/s
    float cycles = length(p) / (30.0 / 480.0) - t * waveSpeed;

    // Windowed onto the ring itself. Left unbounded it ripples the flat core
    // and, far worse, prints concentric rings out across the shadow, which
    // turns the whole thing into a target.
    float waveWin = inset * (1.0 - smoothstep(0.98, 1.20, u)) * mix(1.0, outer, artAmt);
    float wave = sin(cycles * 6.28318) * waveWin * mix(1.0, 0.45, morph) * sharpen;

    // The material colour. Idle is not a pale ring — frame 1 of the reference
    // is four saturated colour blobs (magenta, peach, cyan, violet) filling a
    // soft disc. Mixing those into a single wheel and then blurring it is what
    // made idle read as a muddy halo. The blobs fade out as the droplet
    // resolves, handing over to the sampled vivid wheel.
    float2 b1 = float2( 0.090, -0.085) + float2(0.022 * sin(t * 0.52), 0.016 * cos(t * 0.44));
    float2 b2 = float2(-0.118,  0.010) + float2(0.018 * cos(t * 0.40), 0.014 * sin(t * 0.48));
    float2 b3 = float2( 0.105,  0.095) + float2(0.016 * sin(t * 0.36), 0.017 * cos(t * 0.42));
    float2 b4 = float2(-0.072,  0.108) + float2(0.017 * cos(t * 0.45), 0.014 * sin(t * 0.38));
    // Tight enough that each blob keeps its own hue — k=14 averaged them
    // into a single mauve, which is the idle that did not match frame 1.
    float w1 = exp(-dot(p - b1, p - b1) * 58.0);
    float w2 = exp(-dot(p - b2, p - b2) * 52.0);
    float w3 = exp(-dot(p - b3, p - b3) * 55.0);
    float w4 = exp(-dot(p - b4, p - b4) * 50.0);
    float w0 = exp(-dot(p, p) * 28.0) * 0.55;
    float3 idleMesh = (float3(0.92, 0.86, 0.96) * w0
                     + float3(0.95, 0.38, 0.78) * w1
                     + float3(0.98, 0.82, 0.32) * w2
                     + float3(0.28, 0.58, 0.98) * w3
                     + float3(0.58, 0.22, 0.92) * w4)
                    / max(w0 + w1 + w2 + w3 + w4, 1e-4);
    float idleGrey = dot(idleMesh, float3(0.299, 0.587, 0.114));
    idleMesh = mix(float3(idleGrey), idleMesh, 1.45);

    float3 rimBase = mix(idleMesh, vividWheel(aw + 0.26 * wave), sharpen);
    float3 ringLit = rimBase * ringVar * mix(1.05, 1.15, sharpen) * (1.0 + 0.085 * wave);

    // Pale sheen lives in the outer slope, not on the outline. Sitting it on
    // u = 1 is a 4pt white stroke, which is the dividing line.
    float hi = exp(-pow((u - (uPeak + 0.07)) / 0.09, 2.0)) * (1.0 - artAmt);
    float3 hiCol = paleWheel(aw + 0.26 * wave) * ringVar;

    // A second, weaker band offset further along the same diagonal. Kept faint
    // — at any strength its own rim shows up as a lens edge across the core,
    // now that the chroma boost amplifies whatever sits under it.
    float u2 = length(p - float2(-0.20, 0.10) * S) / Rl;
    float band2 = exp(-pow((u2 - 0.58) / 0.26, 2.0)) * 0.10;
    float3 band2Col = vividWheel(aw - 1.05);

    // ---- artwork -----------------------------------------------------------
    // Sampled with the coordinate folded back onto the outline rather than
    // masked at it. Clipping the artwork puts a step in the colour exactly
    // where the ring is brightest, and that step is what reads as a frame drawn
    // around the picture. Folding instead lets the outline colour carry on into
    // the shadow, which is also what the reference does — its card throws an
    // orange glow where the sun is and a blue one along the bottom.
    float2 uv = (p / S) / max(u, 1.0);
    float bulge = 1.0 - 0.18 * dot(uv, uv) * (1.0 - morph);
    float3 art = artworkColor(uv * bulge, t, 1.0 - smoothstep(0.965, 1.01, u), theme);

    // The core breathes with the haze: centre luminance runs 21↔33 (±22%) on
    // a ~3s period in the capture — the dark disc swells and thins in step
    // with the ring. It damps out as the artwork takes the interior over.
    float coreBreathe = 1.0 + 0.22 * sin(t * 2.1 + 0.6) * (1.0 - 0.85 * artAmt);
    float3 coreDark = float3(0.298, 0.239, 0.353) * mix(1.0, 0.78, morph) * coreBreathe;
    float3 interior = mix(coreDark, art, artAmt);

    // Droplet: the ring *is* the object, so inset still fills it with rim colour.
    // Card: the picture runs through the outline; rim colour only tints the
    // outer glow, mixed with the folded picture so the shadow matches the
    // artwork (blue off the sky, orange off the sun) instead of a second stroke.
    float insetAmt = mix(1.0, inset, sharpen) * (1.0 - artAmt);
    float3 col = mix(interior, ringLit, insetAmt);
    col += band2Col * band2 * sharpen * (1.0 - artAmt);

    float3 glowCol = mix(interior, ringLit, 0.50);
    col = mix(col, glowCol, outer * artAmt);

    float chromaBand = exp(-pow((u - (uPeak - 0.085)) / 0.10, 2.0))
                     * sharpen * (1.0 - artAmt);
    float grey = dot(col, float3(0.3333));
    col = mix(col, grey + (col - grey) * 1.7, chromaBand);

    col += hiCol * hi * 0.22 * sharpen;

    // ---- trigger flash -----------------------------------------------------
    // The capture's centre luminance pops 13→158 (+1120%) within 0.25s of the
    // tap and decays over ~0.4s — generation *announces* itself before the
    // haze gathers. Applied as a whole-object lift plus a warm-white bloom
    // concentrated at the core, so the disc flashes before it dims (condense)
    // and resolves. The bloom's 1/e radius lands just inside the ring.
    float flashAmt = flash * (1.0 - 0.5 * artAmt);
    float3 rgb = col * (1.0 + 0.55 * flashAmt)
               + float3(1.0, 0.97, 0.92) * flashAmt * 0.45 * exp(-dot(p, p) * 14.0);

    // Keep the layer's own square bounds from ever showing through.
    float vignette = 1.0 - smoothstep(0.47, 0.50, length(p));
    alpha *= vignette;

    // Grain lives on the liquid, not on the picture. The reference card's
    // interior is a clean generated image; only the rim still sparkles.
    float interiorArt = artAmt * (1.0 - outer);
    float grain = noise2(position * 0.75 + t * 3.0)
                + noise2(position * 1.90 - t * 2.1) * 0.5;
    float gAmt = mix(0.095, 0.010, interiorArt);
    rgb *= mix(0.90, 0.995, interiorArt) + grain * gAmt;

    rgb = clamp(rgb, 0.0, 1.0);

    // SwiftUI layer effects expect premultiplied colour.
    return half4(half3(rgb * alpha), half(alpha));
}

[[ stitchable ]] half4 appleIdleCloud(float2 position, half4 inputColor, float2 size, float time) {
    return applePlaygroundFlow(position, inputColor, size, time, 0.0, 0.0);
}

[[ stitchable ]] half4 appleLiquid(float2 position, half4 inputColor, float2 size, float time, float morph, float energy, float reveal, float pulse) {
    return applePlaygroundFlow(position, inputColor, size, time, morph, 0.0);
}

[[ stitchable ]] half4 appleArtworkReveal(float2 position, half4 inputColor, float2 size, float time, float reveal, float energy) {
    return inputColor;
}
