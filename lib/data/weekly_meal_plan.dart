import '../models/weekly_plan.dart';

class WeeklyMealPlanData {
  const WeeklyMealPlanData._();

  static const List<DailyMealPlan> days = <DailyMealPlan>[
    DailyMealPlan(
      day: 'Hari 1',
      meals: <PlannedMeal>[
        PlannedMeal(
          name: 'Sarapan roti, telur, pisang',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'bread', grams: 80),
            PlannedFood(foodId: 'egg_boiled', grams: 110),
            PlannedFood(foodId: 'banana', grams: 120),
          ],
          ingredients: <String>['Roti 80 g', 'Telur 2 butir', 'Pisang 1 buah'],
          steps: <String>['Rebus telur 8–10 menit.', 'Panggang roti bila diinginkan.', 'Sajikan bersama pisang.'],
        ),
        PlannedMeal(
          name: 'Nasi ayam bakar & lalapan',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'rice_white', grams: 220),
            PlannedFood(foodId: 'chicken_grilled', grams: 150),
            PlannedFood(foodId: 'vegetables', grams: 120),
          ],
          ingredients: <String>['Nasi matang 220 g', 'Ayam 150 g', 'Kecap 1 sdm', 'Bawang putih', 'Timun, tomat, selada 120 g'],
          steps: <String>['Bumbui ayam lalu ungkep.', 'Bakar sambil dioles kecap.', 'Sajikan dengan nasi dan lalapan.'],
        ),
        PlannedMeal(
          name: 'Ikan bakar, kentang & sayur',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'fish_grilled', grams: 160),
            PlannedFood(foodId: 'potato', grams: 220),
            PlannedFood(foodId: 'vegetables', grams: 120),
          ],
          ingredients: <String>['Ikan 160 g', 'Kentang 220 g', 'Sayuran 120 g', 'Jeruk nipis', 'Bawang putih'],
          steps: <String>['Bumbui dan bakar ikan.', 'Rebus atau panggang kentang.', 'Sajikan bersama sayuran.'],
        ),
      ],
    ),
    DailyMealPlan(
      day: 'Hari 2',
      meals: <PlannedMeal>[
        PlannedMeal(
          name: 'Roti alpukat & telur',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'bread', grams: 80),
            PlannedFood(foodId: 'avocado', grams: 100),
            PlannedFood(foodId: 'egg_boiled', grams: 55),
          ],
          ingredients: <String>['Roti 80 g', 'Alpukat 100 g', 'Telur 1 butir', 'Lada secukupnya'],
          steps: <String>['Haluskan alpukat.', 'Oleskan pada roti.', 'Tambahkan telur rebus dan lada.'],
        ),
        PlannedMeal(
          name: 'Soto ayam + nasi',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'chicken_soto', grams: 400),
            PlannedFood(foodId: 'rice_white', grams: 180),
          ],
          ingredients: <String>['Soto ayam 400 g', 'Nasi 180 g', 'Kol', 'Daun bawang', 'Jeruk nipis'],
          steps: <String>['Panaskan kuah soto.', 'Tambahkan ayam dan sayur.', 'Sajikan dengan nasi.'],
        ),
        PlannedMeal(
          name: 'Tempe, tahu & sayuran',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'tempe_fried', grams: 100),
            PlannedFood(foodId: 'tofu_fried', grams: 100),
            PlannedFood(foodId: 'vegetables', grams: 180),
            PlannedFood(foodId: 'rice_white', grams: 150),
          ],
          ingredients: <String>['Tempe 100 g', 'Tahu 100 g', 'Sayuran 180 g', 'Nasi 150 g', 'Bawang putih'],
          steps: <String>['Bumbui tahu dan tempe.', 'Masak dengan sedikit minyak.', 'Tumis/rebus sayur dan sajikan bersama nasi.'],
        ),
      ],
    ),
    DailyMealPlan(
      day: 'Hari 3',
      meals: <PlannedMeal>[
        PlannedMeal(
          name: 'Telur, roti & apel',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'egg_fried', grams: 120),
            PlannedFood(foodId: 'bread', grams: 70),
            PlannedFood(foodId: 'apple', grams: 180),
          ],
          ingredients: <String>['Telur 2 butir', 'Roti 70 g', 'Apel 1 buah', 'Minyak 1 sdt'],
          steps: <String>['Masak telur dengan sedikit minyak.', 'Panggang roti.', 'Sajikan bersama apel.'],
        ),
        PlannedMeal(
          name: 'Nasi + sate ayam + sayur',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'rice_white', grams: 200),
            PlannedFood(foodId: 'chicken_satay', grams: 150),
            PlannedFood(foodId: 'vegetables', grams: 120),
          ],
          ingredients: <String>['Nasi 200 g', 'Daging ayam 150 g', 'Bumbu kacang secukupnya', 'Sayuran 120 g'],
          steps: <String>['Tusuk dan bakar ayam.', 'Tambahkan bumbu kacang secukupnya.', 'Sajikan dengan nasi dan sayur.'],
        ),
        PlannedMeal(
          name: 'Sup sapi dan kentang',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'soup', grams: 350),
            PlannedFood(foodId: 'beef_grilled', grams: 120),
            PlannedFood(foodId: 'potato', grams: 150),
          ],
          ingredients: <String>['Daging sapi 120 g', 'Kentang 150 g', 'Wortel dan kol', 'Kaldu 350 ml', 'Lada'],
          steps: <String>['Rebus daging hingga empuk.', 'Masukkan kentang dan sayur.', 'Bumbui ringan lalu sajikan.'],
        ),
      ],
    ),
    DailyMealPlan(
      day: 'Hari 4',
      meals: <PlannedMeal>[
        PlannedMeal(
          name: 'Pisang, telur & roti',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'banana', grams: 140),
            PlannedFood(foodId: 'egg_boiled', grams: 110),
            PlannedFood(foodId: 'bread', grams: 70),
          ],
          ingredients: <String>['Pisang 140 g', 'Telur 2 butir', 'Roti 70 g'],
          steps: <String>['Rebus telur.', 'Panggang roti bila suka.', 'Sajikan dengan pisang.'],
        ),
        PlannedMeal(
          name: 'Gado-gado + nasi',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'gado_gado', grams: 350),
            PlannedFood(foodId: 'rice_white', grams: 150),
          ],
          ingredients: <String>['Gado-gado 350 g', 'Nasi 150 g', 'Saus kacang secukupnya'],
          steps: <String>['Rebus sayur.', 'Susun tahu, tempe, telur dan sayur.', 'Tambahkan saus kacang lalu sajikan dengan nasi.'],
        ),
        PlannedMeal(
          name: 'Ayam bakar & kentang',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'chicken_grilled', grams: 160),
            PlannedFood(foodId: 'potato', grams: 220),
            PlannedFood(foodId: 'vegetables', grams: 150),
          ],
          ingredients: <String>['Ayam 160 g', 'Kentang 220 g', 'Sayuran 150 g', 'Bawang', 'Kecap secukupnya'],
          steps: <String>['Bakar ayam hingga matang.', 'Panggang/rebus kentang.', 'Sajikan dengan sayur.'],
        ),
      ],
    ),
    DailyMealPlan(
      day: 'Hari 5',
      meals: <PlannedMeal>[
        PlannedMeal(
          name: 'Roti telur alpukat',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'bread', grams: 80),
            PlannedFood(foodId: 'egg_boiled', grams: 110),
            PlannedFood(foodId: 'avocado', grams: 80),
          ],
          ingredients: <String>['Roti 80 g', 'Telur 2 butir', 'Alpukat 80 g'],
          steps: <String>['Rebus telur.', 'Haluskan alpukat.', 'Susun pada roti.'],
        ),
        PlannedMeal(
          name: 'Rendang + nasi + lalapan',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'rendang_beef', grams: 130),
            PlannedFood(foodId: 'rice_white', grams: 200),
            PlannedFood(foodId: 'vegetables', grams: 100),
          ],
          ingredients: <String>['Rendang 130 g', 'Nasi 200 g', 'Lalapan 100 g'],
          steps: <String>['Panaskan rendang perlahan.', 'Siapkan nasi dan lalapan.', 'Sajikan dengan porsi sesuai daftar.'],
        ),
        PlannedMeal(
          name: 'Ikan goreng + sayur + nasi',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'fish_fried', grams: 150),
            PlannedFood(foodId: 'vegetables', grams: 180),
            PlannedFood(foodId: 'rice_white', grams: 160),
          ],
          ingredients: <String>['Ikan 150 g', 'Sayuran 180 g', 'Nasi 160 g', 'Kunyit', 'Bawang putih'],
          steps: <String>['Bumbui dan masak ikan.', 'Tumis/rebus sayuran.', 'Sajikan dengan nasi.'],
        ),
      ],
    ),
    DailyMealPlan(
      day: 'Hari 6',
      meals: <PlannedMeal>[
        PlannedMeal(
          name: 'Telur, pisang & apel',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'egg_boiled', grams: 110),
            PlannedFood(foodId: 'banana', grams: 120),
            PlannedFood(foodId: 'apple', grams: 150),
            PlannedFood(foodId: 'bread', grams: 60),
          ],
          ingredients: <String>['Telur 2 butir', 'Pisang 1 buah', 'Apel 150 g', 'Roti 60 g'],
          steps: <String>['Rebus telur.', 'Potong buah.', 'Sajikan bersama roti.'],
        ),
        PlannedMeal(
          name: 'Nasi goreng + sayuran',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'fried_rice', grams: 300),
            PlannedFood(foodId: 'vegetables', grams: 120),
          ],
          ingredients: <String>['Nasi matang 250 g', 'Telur 1 butir', 'Sayuran 120 g', 'Bawang', 'Kecap secukupnya'],
          steps: <String>['Tumis bumbu.', 'Masukkan telur, nasi dan sayur.', 'Aduk sampai matang merata.'],
        ),
        PlannedMeal(
          name: 'Bakso kuah + sayuran',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'meatballs_soup', grams: 400),
            PlannedFood(foodId: 'vegetables', grams: 120),
          ],
          ingredients: <String>['Bakso dan kuah 400 g', 'Sayuran 120 g', 'Daun bawang', 'Bawang goreng secukupnya'],
          steps: <String>['Didihkan kuah.', 'Masukkan bakso dan sayur.', 'Sajikan hangat.'],
        ),
      ],
    ),
    DailyMealPlan(
      day: 'Hari 7',
      meals: <PlannedMeal>[
        PlannedMeal(
          name: 'Roti, telur & buah',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'bread', grams: 80),
            PlannedFood(foodId: 'egg_fried', grams: 100),
            PlannedFood(foodId: 'banana', grams: 100),
          ],
          ingredients: <String>['Roti 80 g', 'Telur 2 butir kecil', 'Pisang 100 g'],
          steps: <String>['Masak telur.', 'Panggang roti.', 'Sajikan dengan pisang.'],
        ),
        PlannedMeal(
          name: 'Sate ayam + nasi + lalapan',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'chicken_satay', grams: 160),
            PlannedFood(foodId: 'rice_white', grams: 200),
            PlannedFood(foodId: 'vegetables', grams: 140),
          ],
          ingredients: <String>['Ayam 160 g', 'Nasi 200 g', 'Lalapan 140 g', 'Bumbu kacang secukupnya'],
          steps: <String>['Bakar sate.', 'Siapkan nasi dan lalapan.', 'Sajikan dengan saus secukupnya.'],
        ),
        PlannedMeal(
          name: 'Ikan bakar + kentang + sayur',
          foods: <PlannedFood>[
            PlannedFood(foodId: 'fish_grilled', grams: 170),
            PlannedFood(foodId: 'potato', grams: 200),
            PlannedFood(foodId: 'vegetables', grams: 150),
          ],
          ingredients: <String>['Ikan 170 g', 'Kentang 200 g', 'Sayuran 150 g', 'Jeruk nipis', 'Bawang putih'],
          steps: <String>['Bakar ikan.', 'Rebus/panggang kentang.', 'Sajikan dengan sayuran.'],
        ),
      ],
    ),
  ];
}
