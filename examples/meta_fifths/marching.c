#include "marching.h"
#include "lattice.h"
#include "params.h"

#include <assert.h>
#include <math.h>

static inline float interp(float x1, float x2, float f1, float f2)
{
  return x1 + f1 * (x2 - x1) / (f1 - f2);
  // return x2 - f2 * (x2 - x1) / (f2 - f1);
  // return (x1 + x2) / 2.f;
}

static void add_triangle(struct buffer *b,
                         float x1, float y1, float i1,
                         float x2, float y2, float i2,
                         float x3, float y3, float i3)
{
  i1 = i1 < .0f ? .0f : (i1 > 1.f ? 1.f : i1);
  i2 = i2 < .0f ? .0f : (i2 > 1.f ? 1.f : i2);
  i3 = i3 < .0f ? .0f : (i3 > 1.f ? 1.f : i3);

  if (get_smooth()) {
    i1 = powf(i1, .25f);
    i2 = powf(i2, .25f);
    i3 = powf(i3, .25f);
  } else {
    i1 = i2 = i3 = 1.f;
  }

  const float *bc = get_border_color();
  const float *cc = get_center_color();

  const float r1 = bc[0] + i1 * (cc[0] - bc[0]);
  const float g1 = bc[1] + i1 * (cc[1] - bc[1]);
  const float b1 = bc[2] + i1 * (cc[2] - bc[2]);

  const float r2 = bc[0] + i2 * (cc[0] - bc[0]);
  const float g2 = bc[1] + i2 * (cc[1] - bc[1]);
  const float b2 = bc[2] + i2 * (cc[2] - bc[2]);

  const float r3 = bc[0] + i3 * (cc[0] - bc[0]);
  const float g3 = bc[1] + i3 * (cc[1] - bc[1]);
  const float b3 = bc[2] + i3 * (cc[2] - bc[2]);

  buf_appendv(b, 6, x1, y1, r1, g1, b1, 1.f);
  buf_appendv(b, 6, x2, y2, r2, g2, b2, 1.f);
  buf_appendv(b, 6, x3, y3, r3, g3, b3, 1.f);
}

void marching_squares(struct buffer *b)
{
  buf_clear(b);

  int lw = lattice_w();
  int lh = lattice_h();

  for (int li_1 = 0; li_1 < lw - 1; ++li_1) {
    for (int lj_1 = 0; lj_1 < lh - 1; ++lj_1) {

      const int li_2 = li_1 + 1;
      const int lj_2 = lj_1 + 1;

      const float lx_1 = lattice_x(li_1);
      const float ly_1 = lattice_y(lj_1);
      const float lx_2 = lattice_x(li_2);
      const float ly_2 = lattice_y(lj_2);

      const float v_11 = *lattice_point(li_1, lj_1);
      const float v_21 = *lattice_point(li_2, lj_1);
      const float v_12 = *lattice_point(li_1, lj_2);
      const float v_22 = *lattice_point(li_2, lj_2);

      const int m =
        ((v_11 > 0.f) << 0) |
        ((v_21 > 0.f) << 1) |
        ((v_12 > 0.f) << 2) |
        ((v_22 > 0.f) << 3);

      float ix_1, iy_1,
            ix_2, iy_2,
            ix_3, iy_3,
            ix_4, iy_4;

      switch (m)
      {
        case 0b0000:
          break;

        case 0b0001:
          ix_1 = interp(lx_1, lx_2, v_11, v_21);
          iy_1 = ly_1;
          ix_2 = lx_1;
          iy_2 = interp(ly_1, ly_2, v_11, v_12);
          add_triangle(b, ix_1, iy_1, .0f, ix_2, iy_2, .0f, lx_1, ly_1, v_11);
          break;

        case 0b0010:
          ix_1 = interp(lx_1, lx_2, v_11, v_21);
          iy_1 = ly_1;
          ix_2 = lx_2;
          iy_2 = interp(ly_1, ly_2, v_21, v_22);
          add_triangle(b, ix_1, iy_1, .0f, ix_2, iy_2, .0f, lx_2, ly_1, v_21);
          break;

        case 0b0011:
          ix_1 = lx_1;
          iy_1 = interp(ly_1, ly_2, v_11, v_12);
          ix_2 = lx_2;
          iy_2 = interp(ly_1, ly_2, v_21, v_22);
          add_triangle(b, lx_1, ly_1, v_11, lx_2, ly_1, v_21, ix_1, iy_1, .0f);
          add_triangle(b, lx_2, ly_1, v_21, ix_1, iy_1, .0f, ix_2, iy_2, .0f);
          break;

        case 0b0100:
          ix_1 = lx_1;
          iy_1 = interp(ly_1, ly_2, v_11, v_12);
          ix_2 = interp(lx_1, lx_2, v_12, v_22);
          iy_2 = ly_2;
          add_triangle(b, ix_1, iy_1, .0f, ix_2, iy_2, .0f, lx_1, ly_2, v_12);
          break;

        case 0b0101:
          ix_1 = interp(lx_1, lx_2, v_11, v_21);
          iy_1 = ly_1;
          ix_2 = interp(lx_1, lx_2, v_12, v_22);
          iy_2 = ly_2;
          add_triangle(b, lx_1, ly_1, v_11, ix_1, iy_1, .0f, lx_1, ly_2, v_12);
          add_triangle(b, ix_1, iy_1, .0f, lx_1, ly_2, v_12, ix_2, iy_2, .0f);
          break;

        case 0b0110:
          ix_1 = interp(lx_1, lx_2, v_11, v_21);
          iy_1 = ly_1;
          ix_2 = lx_1;
          iy_2 = interp(ly_1, ly_2, v_11, v_12);
          ix_3 = lx_2;
          iy_3 = interp(ly_1, ly_2, v_21, v_22);
          ix_4 = interp(lx_1, lx_2, v_12, v_22);
          iy_4 = ly_2;
          add_triangle(b, ix_1, iy_1, .0f, ix_2, iy_2, .0f, lx_2, ly_1, v_21);
          add_triangle(b, ix_2, iy_2, .0f, lx_2, ly_1, v_21, lx_1, ly_2, v_12);
          add_triangle(b, lx_1, ly_2, v_12, lx_2, ly_1, v_21, ix_3, iy_3, .0f);
          add_triangle(b, lx_1, ly_2, v_12, ix_3, iy_3, .0f, ix_4, iy_4, .0f);
          break;

        case 0b0111:
          ix_1 = interp(lx_1, lx_2, v_12, v_22);
          iy_1 = ly_2;
          ix_2 = lx_2;
          iy_2 = interp(ly_1, ly_2, v_21, v_22);
          add_triangle(b, lx_1, ly_1, v_11, lx_2, ly_1, v_21, lx_1, ly_2, v_12);
          add_triangle(b, lx_1, ly_2, v_12, ix_1, iy_1, .0f, lx_2, ly_1, v_21);
          add_triangle(b, ix_1, iy_1, .0f, lx_2, ly_1, v_21, ix_2, iy_2, .0f);
          break;

        case 0b1000:
          ix_1 = interp(lx_1, lx_2, v_12, v_22);
          iy_1 = ly_2;
          ix_2 = lx_2;
          iy_2 = interp(ly_1, ly_2, v_21, v_22);
          add_triangle(b, ix_1, iy_1, .0f, ix_2, iy_2, .0f, lx_2, ly_2, v_22);
          break;

        case 0b1001:
          ix_1 = interp(lx_1, lx_2, v_11, v_21);
          iy_1 = ly_1;
          ix_2 = lx_1;
          iy_2 = interp(ly_1, ly_2, v_11, v_12);
          ix_3 = lx_2;
          iy_3 = interp(ly_1, ly_2, v_21, v_22);
          ix_4 = interp(lx_1, lx_2, v_12, v_22);
          iy_4 = ly_2;
          add_triangle(b, lx_1, ly_1, v_11, ix_1, iy_1, .0f, ix_3, iy_3, .0f);
          add_triangle(b, lx_1, ly_1, v_11, ix_3, iy_3, .0f, lx_2, ly_2, v_22);
          add_triangle(b, lx_1, ly_1, v_11, lx_2, ly_2, v_22, ix_2, iy_2, .0f);
          add_triangle(b, ix_2, iy_2, .0f, lx_2, ly_2, v_22, ix_4, iy_4, .0f);
          break;

        case 0b1010:
          ix_1 = interp(lx_1, lx_2, v_11, v_21);
          iy_1 = ly_1;
          ix_2 = interp(lx_1, lx_2, v_12, v_22);
          iy_2 = ly_2;
          add_triangle(b, ix_1, iy_1, .0f, lx_2, ly_1, v_21, ix_2, iy_2, .0f);
          add_triangle(b, lx_2, ly_1, v_21, ix_2, iy_2, .0f, lx_2, ly_2, v_22);
          break;

        case 0b1011:
          ix_1 = lx_1;
          iy_1 = interp(ly_1, ly_2, v_11, v_12);
          ix_2 = interp(lx_1, lx_2, v_12, v_22);
          iy_2 = ly_2;
          add_triangle(b, lx_1, ly_1, v_11, lx_2, ly_1, v_21, lx_2, ly_2, v_22);
          add_triangle(b, lx_1, ly_1, v_11, ix_1, iy_1, .0f, lx_2, ly_2, v_22);
          add_triangle(b, ix_1, iy_1, .0f, lx_2, ly_2, v_22, ix_2, iy_2, .0f);
          break;

        case 0b1100:
          ix_1 = lx_1;
          iy_1 = interp(ly_1, ly_2, v_11, v_12);
          ix_2 = lx_2;
          iy_2 = interp(ly_1, ly_2, v_21, v_22);
          add_triangle(b, ix_1, iy_1, .0f, lx_1, ly_2, v_12, ix_2, iy_2, .0f);
          add_triangle(b, lx_1, ly_2, v_12, ix_2, iy_2, .0f, lx_2, ly_2, v_22);
          break;

        case 0b1101:
          ix_1 = interp(lx_1, lx_2, v_11, v_21);
          iy_1 = ly_1;
          ix_2 = lx_2;
          iy_2 = interp(ly_1, ly_2, v_21, v_22);
          add_triangle(b, lx_1, ly_1, v_11, lx_1, ly_2, v_12, lx_2, ly_2, v_22);
          add_triangle(b, lx_1, ly_1, v_11, ix_1, iy_1, .0f, lx_2, ly_2, v_22);
          add_triangle(b, ix_1, iy_1, .0f, ix_2, iy_2, .0f, lx_2, ly_2, v_22);
          break;

        case 0b1110:
          ix_1 = interp(lx_1, lx_2, v_11, v_21);
          iy_1 = ly_1;
          ix_2 = lx_1;
          iy_2 = interp(ly_1, ly_2, v_11, v_12);
          add_triangle(b, lx_2, ly_1, v_21, lx_2, ly_2, v_22, lx_1, ly_2, v_12);
          add_triangle(b, ix_1, iy_1, .0f, lx_2, ly_1, v_21, lx_1, ly_2, v_12);
          add_triangle(b, ix_1, iy_1, .0f, lx_1, ly_2, v_12, ix_2, iy_2, .0f);
          break;

        case 0b1111:
          add_triangle(b, lx_1, ly_1, v_11, lx_2, ly_1, v_21, lx_1, ly_2, v_12);
          add_triangle(b, lx_2, ly_1, v_21, lx_1, ly_2, v_12, lx_2, ly_2, v_22);
          break;

        default:
          assert(0);
      }
    }
  }
}
