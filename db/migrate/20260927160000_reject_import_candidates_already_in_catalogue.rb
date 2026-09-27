# frozen_string_literal: true

# Rejects the pending import candidates that are already in the catalogue.
#
# The list was made by hand from a production dump: a candidate is on it when
# its name, model number or one of its match keys, reduced to letters and
# digits, is the name or model number of a product or product variant of the
# same brand. Candidates that only look similar (a successor such as "MK2", or
# "EX-M1" against "EX-M1+") are not on the list.
#
# Only rows that are still pending change, so a candidate that a person
# decided in the meantime keeps that decision.
class RejectImportCandidatesAlreadyInCatalogue < ActiveRecord::Migration[8.1]
  # candidate id => product id
  EXISTING = {
    2 => 1677, # 64 Audio Duo -> Duo
    82 => 1676, # 64 Audio Nio -> Nio
    23 => 1671, # 64 Audio Solo -> Solo
    33 => 1673, # 64 Audio U4s -> U4s
    44 => 1672, # 64 Audio U6t -> U6t
    17_792 => 813, # Analog Ethos AE1, Kit -> AE1
    17_791 => 163, # Analog Ethos AE1-C, Kit -> AE1-C
    17_793 => 812, # Analog Ethos Exordium, Kit -> Exordium
    17_794 => 164, # Analog Ethos Legendarium, Custom Kit -> Legendarium
    17_797 => 599, # Analog Ethos Pacific 63 Hermosa Beach Edition -> Pacific 63
    17_795 => 599, # Analog Ethos Pacific 63 -> Pacific 63
    17_796 => 599, # Analog Ethos Pacific 63 -> Pacific 63
    17_798 => 599, # Analog Ethos Pacific 63, Kit -> Pacific 63
    17_799 => 165, # Analog Ethos Requiem -> Requiem
    17_800 => 1802, # Analog Ethos Sereno 300B -> Sereno 300B
    814 => 1, # Audeze LCD-2 Classic -> LCD-2 Classic
    1171 => 1473, # Audiolab 6000A -> 6000A
    9489 => 1680, # Bandoss Avija -> Avija
    1439 => 2, # Bluesound NODE -> Node
    1487 => 591, # Buchardt Audio Anniversary 10 -> Anniversary 10
    1482 => 591, # Buchardt Audio Anniversary 10, Color Edition -> Anniversary 10
    1582 => 1472, # Castle Richmond IV -> Richmond IV
    13_685 => 529, # Cayin CS-6PH -> CS-6PH
    13_655 => 1769, # Cayin HA-300MK3 -> HA-300MK3
    13_681 => 151, # Cayin HA-3A -> HA-3A
    13_694 => 150, # Cayin HA-6A -> HA-6A
    13_678 => 147, # Cayin RU7 -> RU7
    13_810 => 54, # Feliks Audio ARIOSO 300B -> Arioso 300B
    13_811 => 7, # Feliks Audio ELISE -> Elise
    13_809 => 50, # Feliks Audio Envy -> Envy
    13_808 => 52, # Feliks Audio EUFORIA EVO -> Euforia Evo
    13_824 => 129, # Fezz Audio Gaia MM/MC -> Gaia MM
    13_834 => 515, # Fezz Audio Gaia Prestige -> Gaia Prestige
    13_820 => 1679, # Fezz Audio Luna Mini -> Luna Mini
    13_890 => 121, # Fezz Audio Lybra 300B -> Lybra 300B
    13_812 => 1678, # Fezz Audio Mira Ceti MK2 -> Mira Ceti MK2
    13_836 => 119, # Fezz Audio Mira Ceti Mono -> Mira Ceti Mono
    13_891 => 127, # Fezz Audio Omega Lupi -> Omega Lupi
    2436 => 1353, # Fosi Audio V3 -> V3
    2644 => 1547, # HEDD HEDDphone D1 -> HEDDphone D1
    2672 => 1307, # Henry Audio DA 256 -> DA 256
    2692 => 1675, # Hisenior Mega5-EST, Universal -> Mega5EST
    2684 => 1675, # Hisenior Mega5EST, Custom -> Mega5EST
    18_720 => 613, # iBasso D16 -> D16
    18_730 => 601, # iBasso DC-Elite -> DC-Elite
    18_729 => 606, # iBasso DC07PRO -> DC07PRO
    2763 => 604, # iFi GO bar Kensei -> Go bar Kensei
    2919 => 104, # KEF LS50 Meta -> LS50 Meta
    2920 => 105, # KEF LS50 Wireless II -> LS50 Wireless II
    3132 => 584, # Koss KSC75 -> KSC75
    3100 => 585, # Koss Porta Pro -> Porta Pro
    18_838 => 1637, # Layer Audio Design Gen-300B -> Gen-300B
    3158 => 490, # LEAK Stereo 130, Silver -> Stereo 130
    4277 => 519, # Omega Speaker Systems Junior 8 XRS -> Junior 8 XRS
    4276 => 520, # Omega Speaker Systems Super 8 XRS -> Super 8 XRS
    4417 => 113, # Ortofon 2M Black LVB 250 -> 2M Black LVB 250
    4413 => 112, # Ortofon 2M, Bronze -> 2M Bronze
    15_437 => 486, # Pro-Ject The Classic Evo -> The Classic Evo
    15_572 => 518, # Pro-Ject Tube Box DS2 -> Tube Box DS2
    15_913 => 154, # PSVANE UK-6SN7 -> UK-6SN7
    5116 => 611, # Qudelix T71, T71 IEM -> T71
    5152 => 1506, # REL T/5x -> T
    5154 => 1505, # REL Tzero MKIII -> Tzero MKIII
    19_005 => 1348, # Scheu Analog Cantus -> Cantus
    19_006 => 1343, # Scheu Analog CELLO -> Cello
    19_009 => 1345, # Scheu Analog Classic MKII -> Classic MK II
    19_010 => 1342, # Scheu Analog Diamond -> Diamond
    19_031 => 1347, # Scheu Analog Tacco MKII -> Tacco MK II
    16_447 => 1604, # Sono Vera B300 -> B300
    6826 => 1507, # SVS SB-1000 Pro -> SB-1000 Pro
    6906 => 1670, # THIEAUDIO Prestige LTD -> Prestige LTD
    7170 => 779, # Tripowin GranVia -> GranVia
    8330 => 58, # Wharfedale DOVEDALE -> Dovedale
    8261 => 647 # Wharfedale SUPER LINTON -> Super Linton
  }.freeze

  def up
    EXISTING.each do |candidate_id, product_id|
      execute <<~SQL.squish
        UPDATE import_candidates
        SET status = 'rejected',
            decision_note = #{quote("already in the catalogue as product #{product_id}")},
            reviewed_at = NOW(),
            updated_at = NOW()
        WHERE id = #{Integer(candidate_id)} AND status = 'pending'
      SQL
    end
  end

  def down
    execute <<~SQL.squish
      UPDATE import_candidates
      SET status = 'pending', decision_note = NULL, reviewed_at = NULL, updated_at = NOW()
      WHERE id IN (#{EXISTING.keys.join(', ')})
        AND status = 'rejected'
        AND decision_note LIKE 'already in the catalogue as product %'
    SQL
  end
end
