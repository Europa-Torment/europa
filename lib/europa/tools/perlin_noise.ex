defmodule Europa.Tools.PerlinNoise do
  import Bitwise, only: [&&&: 2]

  @perm [
    151,
    160,
    137,
    91,
    90,
    15,
    131,
    13,
    201,
    95,
    96,
    53,
    194,
    233,
    7,
    225,
    140,
    36,
    103,
    30,
    69,
    142,
    8,
    99,
    37,
    240,
    21,
    10,
    23,
    190,
    6,
    148,
    247,
    120,
    234,
    75,
    0,
    26,
    197,
    62,
    94,
    252,
    219,
    203,
    117,
    35,
    11,
    32,
    57,
    177,
    33,
    88,
    237,
    149,
    56,
    87,
    174,
    20,
    125,
    136,
    171,
    168,
    68,
    175,
    74,
    165,
    71,
    134,
    139,
    48,
    27,
    166,
    77,
    146,
    158,
    231,
    83,
    111,
    229,
    122,
    60,
    211,
    133,
    230,
    220,
    105,
    92,
    41,
    55,
    46,
    245,
    40,
    244,
    102,
    143,
    54,
    65,
    25,
    63,
    161,
    1,
    216,
    80,
    73,
    209,
    76,
    132,
    187,
    208,
    89,
    18,
    169,
    200,
    196,
    135,
    130,
    116,
    188,
    159,
    86,
    164,
    100,
    109,
    198,
    173,
    186,
    3,
    64,
    52,
    217,
    226,
    250,
    124,
    123,
    5,
    202,
    38,
    147,
    118,
    126,
    255,
    82,
    85,
    212,
    207,
    206,
    59,
    227,
    47,
    16,
    58,
    17,
    182,
    189,
    28,
    42,
    223,
    183,
    170,
    213,
    119,
    248,
    152,
    2,
    44,
    154,
    163,
    70,
    221,
    153,
    101,
    155,
    167,
    43,
    172,
    9,
    129,
    22,
    39,
    253,
    19,
    98,
    108,
    110,
    79,
    113,
    224,
    232,
    178,
    185,
    112,
    104,
    218,
    246,
    97,
    228,
    251,
    34,
    242,
    193,
    238,
    210,
    144,
    12,
    191,
    179,
    162,
    241,
    81,
    51,
    145,
    235,
    249,
    14,
    239,
    107,
    49,
    192,
    214,
    31,
    181,
    199,
    106,
    157,
    184,
    84,
    204,
    176,
    115,
    121,
    50,
    45,
    127,
    4,
    150,
    254,
    138,
    236,
    205,
    93,
    222,
    114,
    67,
    29,
    24,
    72,
    243,
    141,
    128,
    195,
    78,
    66,
    215,
    61,
    156,
    180
  ]

  @perm512 List.to_tuple(@perm ++ @perm)

  @doc """
  Returns perlin noise value for `x` and `y` coordinates.
  Value vill be in `-1.0..1.0`.
  """
  @spec noise(x :: number, y :: number) :: number()
  def noise(x, y) when is_number(x) and is_number(y) do
    x0 = floor_int(x)
    x1 = x0 + 1
    y0 = floor_int(y)
    y1 = y0 + 1

    dx = x - x0
    dy = y - y0

    sx = fade(dx)
    sy = fade(dy)

    nw = grad(hash(x0, y0), dx, dy)
    ne = grad(hash(x1, y0), dx - 1, dy)
    sw = grad(hash(x0, y1), dx, dy - 1)
    se = grad(hash(x1, y1), dx - 1, dy - 1)

    n = lerp(sx, nw, ne)
    s = lerp(sx, sw, se)
    lerp(sy, n, s)
  end

  defp floor_int(x) when x >= 0, do: trunc(x)

  defp floor_int(x) do
    t = trunc(x)
    if t == x, do: t, else: t - 1
  end

  defp fade(t), do: t * t * t * (t * (t * 6 - 15) + 10)

  defp lerp(t, a, b), do: a + t * (b - a)

  defp hash(ix, iy) do
    ix_masked = ix &&& 255
    iy_masked = iy &&& 255
    i = elem(@perm512, ix_masked + elem(@perm512, iy_masked))
    elem(@perm512, i)
  end

  defp grad(hash, dx, dy) do
    case hash &&& 7 do
      0 -> dx + dy
      1 -> -dx + dy
      2 -> dx - dy
      3 -> -dx - dy
      4 -> dx
      5 -> -dx
      6 -> dy
      7 -> -dy
    end
  end
end
