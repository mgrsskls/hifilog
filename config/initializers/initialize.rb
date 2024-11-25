PgSearch.multisearch_options = {
	ignoring: :accents,
	using: {
		tsearch: {
			any_word: true,
			highlight: {
				StartSel: '<mark>',
				StopSel: '</mark>',
				MaxFragments: 3,
				FragmentDelimiter: ' […] '
			}
		}
	},
	ranked_by: ':trigram'
}

APP_NAME = 'HiFi Log'
CURRENCIES = [
	{
		id: "AFN",
		name: "AFN (Afghanistan Afghani)",
		api: true,
	},
	{
		id: "ALL",
		name: "ALL (Albanian Lek)",
		api: true,
	},
	{
		id: "DZD",
		name: "DZD (Algerian Dinar)",
		api: true,
	},
	{
		id: "AOA",
		name: "AOA (Angolan New Kwanza)",
		api: true,
	},
	{
		id: "ARS",
		name: "ARS (Argentine Peso)",
		api: true,
	},
	{
		id: "AMD",
		name: "AMD (Armenian Dram)",
		api: true,
	},
	{
		id: "AWG",
		name: "AWG (Aruba Florin)",
		api: false,
	},
	{
		id: "AUD",
		name: "AUD (Australian Dollar)",
		api: true,
	},
	{
		id: "AZN",
		name: "AZN (Azerbaijani Manat)",
		api: true,
	},
	{
		id: "BSD",
		name: "BSD (Bahamian Dollar)",
		api: true,
	},
	{
		id: "BHD",
		name: "BHD (Bahraini Dinar)",
		api: true,
	},
	{
		id: "BDT",
		name: "BDT (Bangladesh Taka)",
		api: true,
	},
	{
		id: "BBD",
		name: "BBD (Barbados Dollar)",
		api: false,
	},
	{
		id: "BYR",
		name: "BYR (Belarus Ruble)",
		api: true,
	},
	{
		id: "BZD",
		name: "BZD (Belize Dollar)",
		api: false,
	},
	{
		id: "BMD",
		name: "BMD (Bermuda Dollar)",
		api: false,
	},
	{
		id: "BTN",
		name: "BTN (Bhutan Ngultrum)",
		api: false,
	},
	{
		id: "BOB",
		name: "BOB (Bolivian Boliviano)",
		api: true,
	},
	{
		id: "BAM",
		name: "BAM (Bosnian Marka)",
		api: false,
	},
	{
		id: "BWP",
		name: "BWP (Botswana Pula)",
		api: true,
	},
	{
		id: "BRL",
		name: "BRL (Brazilian Real)",
		api: true,
	},
	{
		id: "GBP",
		name: "GBP (British Pound)",
		api: true,
	},
	{
		id: "BND",
		name: "BND (Brunei Dollar)",
		api: true,
	},
	{
		id: "BGN",
		name: "BGN (Bulgarian Lev)",
		api: true,
	},
	{
		id: "BIF",
		name: "BIF (Burundi Franc)",
		api: true,
	},
	{
		id: "KHR",
		name: "KHR (Cambodia Riel)",
		api: true,
	},
	{
		id: "CAD",
		name: "CAD (Canadian Dollar)",
		api: true,
	},
	{
		id: "CVE",
		name: "CVE (Cape Verde Escudo)",
		api: true,
	},
	{
		id: "KYD",
		name: "KYD (Cayman Islands Dollar)",
		api: true,
	},
	{
		id: "CLP",
		name: "CLP (Chilean Peso)",
		api: true,
	},
	{
		id: "CNY",
		name: "CNY (Chinese Yuan)",
		api: true,
	},
	{
		id: "COP",
		name: "COP (Colombian Peso)",
		api: true,
	},
	{
		id: "KMF",
		name: "KMF (Comoros Franc)",
		api: true,
	},
	{
		id: "CDF",
		name: "CDF (Congolese Franc)",
		api: true,
	},
	{
		id: "CRC",
		name: "CRC (Costa Rica Colon)",
		api: true,
	},
	{
		id: "HRK",
		name: "HRK (Croatian Kuna)",
		api: false,
	},
	{
		id: "CUP",
		name: "CUP (Cuban Peso)",
		api: false,
	},
	{
		id: "CZK",
		name: "CZK (Czech Koruna)",
		api: true,
	},
	{
		id: "DKK",
		name: "DKK (Danish Krone)",
		api: true,
	},
	{
		id: "DJF",
		name: "DJF (Dijibouti Franc)",
		api: true,
	},
	{
		id: "DOP",
		name: "DOP (Dominican Peso)",
		api: true,
	},
	{
		id: "XCD",
		name: "XCD (East Caribbean Dollar)",
		api: false,
	},
	{
		id: "EGP",
		name: "EGP (Egyptian Pound)",
		api: true,
	},
	{
		id: "GHS",
		name: "GHS (Ghanaian cedi)",
		api: true,
	},
	{
		id: "SVC",
		name: "SVC (El Salvador Colon)",
		api: true,
	},
	{
		id: "RSD",
		name: "RSD (Serbia Dinar)",
		api: true,
	},
	{
		id: "ERN",
		name: "ERN (Eritrea Nakfa)",
		api: true,
	},
	{
		id: "ETB",
		name: "ETB (Ethiopian Birr)",
		api: true,
	},
	{
		id: "EUR",
		name: "Euro (EUR)",
		api: true,
	},
	{
		id: "FKP",
		name: "FKP (Falkland Islands Pound)",
		api: false,
	},
	{
		id: "FJD",
		name: "FJD (Fiji Dollar)",
		api: true,
	},
	{
		id: "GMD",
		name: "GMD (Gambian Dalasi)",
		api: true,
	},
	{
		id: "GEL",
		name: "GEL (Georgian Lari)",
		api: true,
	},
	{
		id: "GHC",
		name: "GHC (Ghanian Cedi)",
		api: false,
	},
	{
		id: "GIP",
		name: "GIP (Gibraltar Pound)",
		api: false,
	},
	{
		id: "GTQ",
		name: "GTQ (Guatemala Quetzal)",
		api: true,
	},
	{
		id: "GGP",
		name: "GGP (Guernsey Pound)",
		api: false,
	},
	{
		id: "GNF",
		name: "GNF (Guinea Franc)",
		api: true,
	},
	{
		id: "GYD",
		name: "GYD (Guyana Dollar)",
		api: true,
	},
	{
		id: "HTG",
		name: "HTG (Haiti Gourde)",
		api: true,
	},
	{
		id: "HNL",
		name: "HNL (Honduras Lempira)",
		api: true,
	},
	{
		id: "HKD",
		name: "HKD (Hong Kong Dollar)",
		api: true,
	},
	{
		id: "HUF",
		name: "HUF (Hungarian Forint)",
		api: true,
	},
	{
		id: "ISK",
		name: "ISK (Iceland Krona)",
		api: true,
	},
	{
		id: "INR",
		name: "INR (Indian Rupee)",
		api: true,
	},
	{
		id: "IDR",
		name: "IDR (Indonesian Rupiah)",
		api: true,
	},
	{
		id: "IRR",
		name: "IRR (Iran Rial)",
		api: true,
	},
	{
		id: "IQD",
		name: "IQD (Iraqi Dinar)",
		api: true,
	},
	{
		id: "IMP",
		name: "IMP (Isle of Man Pound)",
		api: false,
	},
	{
		id: "ILS",
		name: "ILS (Israeli Shekel)",
		api: true,
	},
	{
		id: "JMD",
		name: "JMD (Jamaican Dollar)",
		api: true,
	},
	{
		id: "JPY",
		name: "JPY (Japanese Yen)",
		api: true,
	},
	{
		id: "JEP",
		name: "JEP (Jersey Pound)",
		api: false,
	},
	{
		id: "JOD",
		name: "JOD (Jordanian Dinar)",
		api: true,
	},
	{
		id: "KZT",
		name: "KZT (Kazakhstan Tenge)",
		api: true,
	},
	{
		id: "KES",
		name: "KES (Kenyan Shilling)",
		api: true,
	},
	{
		id: "KRW",
		name: "KRW (Korean Won)",
		api: true,
	},
	{
		id: "KWD",
		name: "KWD (Kuwaiti Dinar)",
		api: false,
	},
	{
		id: "KGS",
		name: "KGS (Kyrgyzstan Som)",
		api: true,
	},
	{
		id: "LAK",
		name: "LAK (Lao Kip)",
		api: true,
	},
	{
		id: "LBP",
		name: "LBP (Lebanese Pound)",
		api: true,
	},
	{
		id: "LSL",
		name: "LSL (Lesotho Loti)",
		api: true,
	},
	{
		id: "LRD",
		name: "LRD (Liberian Dollar)",
		api: true,
	},
	{
		id: "LYD",
		name: "LYD (Libyan Dinar)",
		api: true,
	},
	{
		id: "MOP",
		name: "MOP (Macau Pataca)",
		api: true,
	},
	{
		id: "MKD",
		name: "MKD (Macedonian Denar)",
		api: true,
	},
	{
		id: "MGF",
		name: "MGF (Malagasy Franc)",
		api: false,
	},
	{
		id: "MWK",
		name: "MWK (Malawi Kwacha)",
		api: true,
	},
	{
		id: "MYR",
		name: "MYR (Malaysian Ringgit)",
		api: true,
	},
	{
		id: "MVR",
		name: "MVR (Maldives Rufiyaa)",
		api: true,
	},
	{
		id: "MRO",
		name: "MRO (Mauritania Ougulya)",
		api: false,
	},
	{
		id: "MUR",
		name: "MUR (Mauritius Rupee)",
		api: true,
	},
	{
		id: "MXN",
		name: "MXN (Mexican Peso)",
		api: true,
	},
	{
		id: "MDL",
		name: "MDL (Moldovan Leu)",
		api: true,
	},
	{
		id: "MNT",
		name: "MNT (Mongolian Tugrik)",
		api: true,
	},
	{
		id: "MAD",
		name: "MAD (Moroccan Dirham)",
		api: true,
	},
	{
		id: "MGA",
		name: "MGA (Malagasy ariary)",
		api: true,
	},
	{
		id: "MZN",
		name: "MZN (Mozambique Metical)",
		api: true,
	},
	{
		id: "MMK",
		name: "MMK (Myanmar Kyat)",
		api: true,
	},
	{
		id: "NAD",
		name: "NAD (Namibian Dollar)",
		api: true,
	},
	{
		id: "NPR",
		name: "NPR (Nepalese Rupee)",
		api: true,
	},
	{
		id: "ANG",
		name: "ANG (Neth Antilles Guilder)",
		api: false,
	},
	{
		id: "NZD",
		name: "NZD (New Zealand Dollar)",
		api: true,
	},
	{
		id: "NIO",
		name: "NIO (Nicaragua Cordoba)",
		api: true,
	},
	{
		id: "NGN",
		name: "NGN (Nigerian Naira)",
		api: true,
	},
	{
		id: "KPW",
		name: "KPW (North Korean Won)",
		api: false,
	},
	{
		id: "NOK",
		name: "NOK (Norwegian Krone)",
		api: true,
	},
	{
		id: "OMR",
		name: "OMR (Omani Rial)",
		api: true,
	},
	{
		id: "XPF",
		name: "XPF (Pacific Franc)",
		api: true,
	},
	{
		id: "PKR",
		name: "PKR (Pakistani Rupee)",
		api: true,
	},
	{
		id: "PAB",
		name: "PAB (Panama Balboa)",
		api: true,
	},
	{
		id: "PGK",
		name: "PGK (Papua New Guinea Kina)",
		api: true,
	},
	{
		id: "PYG",
		name: "PYG (Paraguayan Guarani)",
		api: true,
	},
	{
		id: "PEN",
		name: "PEN (Peruvian Nuevo Sol)",
		api: true,
	},
	{
		id: "PHP",
		name: "PHP (Philippine Peso)",
		api: true,
	},
	{
		id: "PLN",
		name: "PLN (Polish Zloty)",
		api: true,
	},
	{
		id: "QAR",
		name: "QAR (Qatar Rial)",
		api: true,
	},
	{
		id: "RON",
		name: "RON (Romanian Leu)",
		api: true,
	},
	{
		id: "RUB",
		name: "RUB (Russian Rouble)",
		api: true,
	},
	{
		id: "RWF",
		name: "RWF (Rwanda Franc)",
		api: true,
	},
	{
		id: "WST",
		name: "WST (Samoa Tala)",
		api: false,
	},
	{
		id: "STD",
		name: "STN (Sao Tome Dobra)",
		api: true,
	},
	{
		id: "SAR",
		name: "SAR (Saudi Arabian Riyal)",
		api: true,
	},
	{
		id: "SCR",
		name: "SCR (Seychelles Rupee)",
		api: true,
	},
	{
		id: "SLL",
		name: "SLL (Sierra Leone Leone)",
		api: true,
	},
	{
		id: "XAG",
		name: "XAG (Silver Ounces)",
		api: false,
	},
	{
		id: "SGD",
		name: "SGD (Singapore Dollar)",
		api: true,
	},
	{
		id: "SBD",
		name: "SBD (Solomon Islands Dollar)",
		api: false,
	},
	{
		id: "SOS",
		name: "SOS (Somali Shilling)",
		api: true,
	},
	{
		id: "ZAR",
		name: "ZAR (South African Rand)",
		api: true,
	},
	{
		id: "LKR",
		name: "LKR (Sri Lanka Rupee)",
		api: true,
	},
	{
		id: "SHP",
		name: "SHP (St Helena Pound)",
		api: false,
	},
	{
		id: "SSP",
		name: "SSP (South Sudanese pound)",
		api: true,
	},
	{
		id: "SDG",
		name: "SDG (Sudanese Pound)",
		api: true,
	},
	{
		id: "SRD",
		name: "SRD (Surinam Dollar)",
		api: true,
	},
	{
		id: "SZL",
		name: "SZL (Swaziland Lilageni)",
		api: true,
	},
	{
		id: "SEK",
		name: "SEK (Swedish Krona)",
		api: true,
	},
	{
		id: "CHF",
		name: "CHF (Swiss Franc)",
		api: true,
	},
	{
		id: "SYP",
		name: "SYP (Syrian Pound)",
		api: true,
	},
	{
		id: "TWD",
		name: "TWD (Taiwan Dollar)",
		api: true,
	},
	{
		id: "TJS",
		name: "TJS (Tajikistani somoni)",
		api: true,
	},
	{
		id: "TZS",
		name: "TZS (Tanzanian Shilling)",
		api: true,
	},
	{
		id: "THB",
		name: "THB (Thai Baht)",
		api: true,
	},
	{
		id: "TOP",
		name: "TOP (Tonga Pa'anga)",
		api: false,
	},
	{
		id: "TTD",
		name: "TTD (Trinidad&Tobago Dollar)",
		api: true,
	},
	{
		id: "TND",
		name: "TND (Tunisian Dinar)",
		api: true,
	},
	{
		id: "TRY",
		name: "TRY (Turkish Lira)",
		api: false,
	},
	{
		id: "TMT",
		name: "TMT (Turkmenistani Manat)",
		api: false,
	},
	{
		id: "USD",
		name: "U.S. Dollar (USD)",
		api: true,
	},
	{
		id: "AED",
		name: "AED (UAE Dirham)",
		api: true,
	},
	{
		id: "UGX",
		name: "UGX (Ugandan Shilling)",
		api: true,
	},
	{
		id: "UAH",
		name: "UAH (Ukraine Hryvnia)",
		api: true,
	},
	{
		id: "UYU",
		name: "UYU (Uruguayan New Peso)",
		api: false,
	},
	{
		id: "UZS",
		name: "UZS (Uzbekistani Sum)",
		api: true,
	},
	{
		id: "VUV",
		name: "VUV (Vanuatu Vatu)",
		api: false,
	},
	{
		id: "VEB",
		name: "VEB (Venezuelan Bolivar)",
		api: false,
	},
	{
		id: "VND",
		name: "VND (Vietnam Dong)",
		api: true,
	},
	{
		id: "YER",
		name: "YER (Yemen Riyal)",
		api: true,
	},
	{
		id: "YUM",
		name: "YUM (Yugoslav Dinar)",
		api: false,
	},
	{
		id: "ZRN",
		name: "ZRN (Zaire New Zaire)",
		api: false,
	},
	{
		id: "ZMK",
		name: "ZMK (Zambian Kwacha)",
		api: false,
	},
	{
		id: "ZWD",
		name: "ZWD (Zimbabwe Dollar)",
		api: false,
	},
].freeze

BOTS = [
	"AdsBot",
	"AhrefsBot",
	"Amazonbot",
	"anthropic-ai",
	"Applebot",
	"AwarioRssBot",
	"AwarioSmartBot",
	"Bytespider",
	"CCBot",
	"ChatGPT-User",
	"Claude-Web",
	"ClaudeBot",
	"cohere-ai",
	"DataForSeoBot",
	"Facebook",
	"FriendlyCrawler",
	"Google",
	"GPTBot",
	"ImagesiftBot",
	"magpie-crawler",
	"Meltwater",
	"meta-externalagent",
	"omgili",
	"peer39_crawler",
	"PerplexityBot",
	"PiplBot",
	"Seekr",
	"semrush",
	"Twitterbot",
	"YouBot",
].freeze
