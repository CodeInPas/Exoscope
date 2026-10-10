unit uKeplerPhysics;

{$mode objfpc}{$H+}

interface

uses
  Math;

const
  { Konstanta Astrofisika }
  DAYS_IN_YEAR = 365.25;
  SOLAR_RADIUS_TO_EARTH = 109.2; // 1 Radius Matahari = ~109.2 Radius Bumi

type
  { Klasifikasi Spektra Bintang Morgan-Keenan }
  TStarClass = (scO, scB, scA, scF, scG, scK, scM);

  { Properti Fisik Bintang Induk }
  TStarProperties = record
    StarClass: TStarClass;
    ClassName: string;
    Mass: Double;        { Satuan Massa Matahari (M_sun) }
    Radius: Double;      { Satuan Radius Matahari (R_sun) }
    Luminosity: Double;  { Satuan Luminositas Matahari (L_sun) }
    Temperature: Double; { Suhu Permukaan (Kelvin) }
    PeakWavelength: Double; { Panjang Gelombang Puncak (nm) untuk mekanik Bandwidth }
  end;

  { Record untuk menampung data batas Habitable Zone (Zona Laik Huni) }
  THabitableZone = record
    InnerBoundAU: Double;
    OuterBoundAU: Double;
  end;

  { TKeplerPhysics }
  TKeplerPhysics = class
  public
    { Menarik rentang profil fisik bintang berdasarkan kelasnya }
    class function GetStarProperties(AClass: TStarClass): TStarProperties;

    { Menghasilkan bintang secara acak dengan distribusi probabilitas astronomi nyata }
    class function GenerateRandomStar: TStarProperties;

    class function CalculateSemiMajorAxis(APeriodDays, AStarMassSolar: Double): Double;
    class function CalculatePlanetRadius(ATransitDepth, AStarRadiusSolar: Double): Double;
    class function CalculateHabitableZone(AStarLuminositySolar: Double): THabitableZone;
    class function IsHabitable(ASemiMajorAxisAU: Double; AZone: THabitableZone): Boolean;

    { Klasifikasi Tipe Planet (Planetary Typology) }
    class function GetPlanetaryTypology(APlanetRadiusEarth, ASemiMajorAxisAU: Double; AZone: THabitableZone): string;
  end;

implementation

{ TKeplerPhysics }

class function TKeplerPhysics.GetStarProperties(AClass: TStarClass): TStarProperties;
begin
  Result.StarClass := AClass;

  // Menggunakan rentang acak dalam batas wajar setiap klasifikasi
  case AClass of
    scO: begin // Blue Giants (Ekstrem & Langka)
      Result.ClassName := 'O-Class (Blue Giant)';
      Result.Mass := 16.0 + Random(44);
      Result.Radius := 6.6 + Random(15);
      Result.Luminosity := 30000 + Random(70000);
      Result.Temperature := 30000 + Random(20000);
    end;
    scB: begin // Blue-White
      Result.ClassName := 'B-Class (Blue-White)';
      Result.Mass := 2.1 + Random(14);
      Result.Radius := 1.8 + Random(5);
      Result.Luminosity := 25 + Random(29000);
      Result.Temperature := 10000 + Random(20000);
    end;
    scA: begin // White
      Result.ClassName := 'A-Class (White)';
      Result.Mass := 1.4 + (Random * 0.7);
      Result.Radius := 1.4 + (Random * 0.4);
      Result.Luminosity := 5.0 + Random(20);
      Result.Temperature := 7500 + Random(2500);
    end;
    scF: begin // Yellow-White
      Result.ClassName := 'F-Class (Yellow-White)';
      Result.Mass := 1.04 + (Random * 0.36);
      Result.Radius := 1.15 + (Random * 0.25);
      Result.Luminosity := 1.5 + Random(3);
      Result.Temperature := 6000 + Random(1500);
    end;
    scG: begin // Yellow Dwarf (Seperti Matahari Kita)
      Result.ClassName := 'G-Class (Yellow Dwarf)';
      Result.Mass := 0.8 + (Random * 0.24);
      Result.Radius := 0.96 + (Random * 0.19);
      Result.Luminosity := 0.6 + (Random * 0.9);
      Result.Temperature := 5200 + Random(800);
    end;
    scK: begin // Orange Dwarf
      Result.ClassName := 'K-Class (Orange Dwarf)';
      Result.Mass := 0.45 + (Random * 0.35);
      Result.Radius := 0.7 + (Random * 0.26);
      Result.Luminosity := 0.08 + (Random * 0.52);
      Result.Temperature := 3700 + Random(1500);
    end;
    scM: begin // Red Dwarf (Paling Umum di Galaksi)
      Result.ClassName := 'M-Class (Red Dwarf)';
      Result.Mass := 0.08 + (Random * 0.37);
      Result.Radius := 0.1 + (Random * 0.6);
      Result.Luminosity := 0.001 + (Random * 0.07);
      Result.Temperature := 2400 + Random(1300);
    end;
  end;

  // Hukum Pergeseran Wien (Wien's Displacement Law)
  // Digunakan untuk mekanik game: Menentukan di Bandwidth mana gelombang paling mudah dideteksi
  Result.PeakWavelength := 2897771.9 / Result.Temperature;
end;

class function TKeplerPhysics.GenerateRandomStar: TStarProperties;
var
  Roll: Integer;
  SelectedClass: TStarClass;
begin
  // Simulasi probabilitas galaksi nyata (1000 lemparan)
  Roll := Random(1000);
  if Roll < 1 then SelectedClass := scO          // 0.1% (Sangat Langka)
  else if Roll < 5 then SelectedClass := scB     // 0.4%
  else if Roll < 15 then SelectedClass := scA    // 1.0%
  else if Roll < 45 then SelectedClass := scF    // 3.0%
  else if Roll < 125 then SelectedClass := scG   // 8.0% (Seperti Matahari)
  else if Roll < 255 then SelectedClass := scK   // 13.0%
  else SelectedClass := scM;                     // 74.5% (Sangat Umum)

  Result := GetStarProperties(SelectedClass);
end;

class function TKeplerPhysics.CalculateSemiMajorAxis(APeriodDays, AStarMassSolar: Double): Double;
var
  PeriodYears: Double;
begin
  if (APeriodDays <= 0) or (AStarMassSolar <= 0) then Exit(0);
  PeriodYears := APeriodDays / DAYS_IN_YEAR;
  Result := Power(AStarMassSolar * Sqr(PeriodYears), 1.0 / 3.0);
end;

class function TKeplerPhysics.CalculatePlanetRadius(ATransitDepth, AStarRadiusSolar: Double): Double;
begin
  if (ATransitDepth <= 0) or (AStarRadiusSolar <= 0) then Exit(0);
  Result := (AStarRadiusSolar * Sqrt(ATransitDepth)) * SOLAR_RADIUS_TO_EARTH;
end;

class function TKeplerPhysics.CalculateHabitableZone(AStarLuminositySolar: Double): THabitableZone;
begin
  if AStarLuminositySolar <= 0 then
  begin
    Result.InnerBoundAU := 0;
    Result.OuterBoundAU := 0;
    Exit;
  end;
  Result.InnerBoundAU := Sqrt(AStarLuminositySolar / 1.1);
  Result.OuterBoundAU := Sqrt(AStarLuminositySolar / 0.53);
end;

class function TKeplerPhysics.IsHabitable(ASemiMajorAxisAU: Double; AZone: THabitableZone): Boolean;
begin
  Result := (ASemiMajorAxisAU >= AZone.InnerBoundAU) and
            (ASemiMajorAxisAU <= AZone.OuterBoundAU);
end;

class function TKeplerPhysics.GetPlanetaryTypology(APlanetRadiusEarth, ASemiMajorAxisAU: Double; AZone: THabitableZone): string;
begin
  // Raksasa Gas (Jupiter-like atau Hot Jupiter)
  if APlanetRadiusEarth >= 6.0 then
  begin
    if ASemiMajorAxisAU < AZone.InnerBoundAU then
      Result := 'HOT JUPITER'
    else
      Result := 'GAS GIANT';
  end
  // Raksasa Es (Neptune-like)
  else if APlanetRadiusEarth >= 4.0 then
  begin
    Result := 'ICE GIANT';
  end
  // Planet Berbatu (Rocky / Terrestrial)
  else
  begin
    if ASemiMajorAxisAU < AZone.InnerBoundAU then
      Result := 'LAVA WORLD'
    else if ASemiMajorAxisAU > AZone.OuterBoundAU then
      Result := 'ICE WORLD'
    else
    begin
      // Di dalam Zona Laik Huni (Habitable Zone)!
      if APlanetRadiusEarth >= 1.5 then
        Result := 'SUPER-EARTH'
      else
        Result := 'TERRESTRIAL';
    end;
  end;
end;

end.
