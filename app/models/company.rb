class Company < ApplicationRecord
  has_one_attached :profile_image
  has_many :recommendations, dependent: :destroy
  has_many :networks, dependent: :destroy
  has_many :units, dependent: :destroy
  belongs_to :user, optional: true

  INDUSTRIES = [
    [ "Select Industry", "", { disabled: true, selected: true } ],
    [ "Agriculture", "AGRICULTURE" ],
    [ "Academia", "ACADEMIA" ],
    [ "Animal care", "ANIMAL" ],
    [ "Apparel", "APPAREL" ],
    [ "Banking", "BANKING" ],
    [ "Beauty and Cosmetics", "BEAUTY" ],
    [ "Biotechnology", "BIOTECHNOLOGY" ],
    [ "Business Services", "BUSINESS_SERVICES" ],
    [ "Chemicals", "CHEMICALS" ],
    [ "Communications", "COMMUNICATIONS" ],
    [ "Construction", "CONSTRUCTION" ],
    [ "Consulting", "CONSULTING" ],
    [ "Distribution", "DISTRIBUTION" ],
    [ "Education", "EDUCATION" ],
    [ "Electronics", "ELECTRONICS" ],
    [ "Energy", "ENERGY" ],
    [ "Engineering", "ENGINEERING" ],
    [ "Entertainment", "ENTERTAINMENT" ],
    [ "Environmental", "ENVIRONMENTAL" ],
    [ "Finance", "FINANCE" ],
    [ "Food and Beverage", "FOOD_BEVERAGE" ],
    [ "Government and Public services", "GOVERNMENT" ],
    [ "Grant and Fundraising", "GRANT" ],
    [ "Healthcare", "HEALTHCARE" ],
    [ "Hospitality", "HOSPITALITY" ],
    [ "HR and Recruitment", "HR" ],
    [ "Insurance", "INSURANCE" ],
    [ "Legal Services", "LEGAL" ],
    [ "Machinery", "MACHINERY" ],
    [ "Manufacturing", "MANUFACTURING" ],
    [ "Media", "MEDIA" ],
    [ "Medical Equipment and Supplies", "MEDICAL_EQUIPMENT_AND_SUPPLIES" ],
    [ "Not for profit", "NOT_FOR_PROFIT" ],
    [ "Oil and Gas", "OIL_GAS" ],
    [ "Pharmaceutical", "PHARMACEUTICAL" ],
    [ "Real Estate", "REAL_ESTATE" ],
    [ "Recreation", "RECREATION" ],
    [ "Recruitment", "RECRUITMENT" ],
    [ "Research (non-academic)", "RESEARCH" ],
    [ "Retail", "RETAIL" ],
    [ "Security Services", "SECURITY" ],
    [ "Shipping", "SHIPPING" ],
    [ "Software and IT", "SOFTWARE" ],
    [ "Technology Hardware", "TECHNOLOGY" ],
    [ "Telecommunications", "TELECOMMUNICATIONS" ],
    [ "Transportation", "TRANSPORTATION" ],
    [ "Travel", "TRAVEL" ],
    [ "Utilities", "UTILITIES" ],
    [ "Other", "OTHER" ]
  ]

  OWNERSHIPS = [
    [ "Select Ownership", "", { disabled: true, selected: true } ],
    [ "Sole proprietorship", "SOLE" ],
    [ "General partnership", "GENERAL" ],
    [ "Limited partnership", "LIMITED" ],
    [ "Association/Non-profit/NGO", "ASSOCIATION" ],
    [ "Private limited company", "PRIVATE_LIMITED" ],
    [ "Public limited company", "PUBLIC_LIMITED" ],
    [ "Limited Cooperative", "LIMITED_COOPERATIVE" ],
    [ "Single member close corporation", "SINGLE_MEMBER" ],
    [ "Unincorporated investment fund", "UNINCORPORATED_FUND" ],
    [ "Investment trust", "INVESTMENT_TRUST" ],
    [ "Investment company with variable capital", "INVESTMENT_COMPANY" ],
    [ "Economic interest grouping", "ECONOMIC_INTEREST" ],
    [ "Publicly traded partnership", "PUBLICLY_TRADED" ],
    [ "Property company", "PROPERTY_COMPANY" ],
    [ "Single shareholder limited company", "SINGLE_SHAREHOLDER" ],
    [ "Government owned corporation", "GOVERNMENT_OWNED" ],
    [ "Unincorporated association", "UNINCORPORATED_ASSOCIATION" ],
    [ "Incorporated association", "INCORPORATED_ASSOCIATION" ],
    [ "Independent contractor", "INDEPENDENT_CONTRACTOR" ],
    [ "Other", "OTHER" ]
  ]

  TAX_ID_TYPES = [
    [ "ABN", "ABN" ],
    [ "BN", "BN" ],
    [ "CST", "CST" ],
    [ "ORG", "ORG" ],
    [ "TAX", "TAX" ],
    [ "TIN", "TIN" ],
    [ "VAT", "VAT" ],
    [ "VSK", "VSK" ],
    [ "Other", "OTHER" ]
  ]

  SIZES = [
    [ "Select Company Size", "", { disabled: true, selected: true } ],
    [ "1 employee (just me)", "ONE" ],
    [ "2-15 employees", "FROM2TO15" ],
    [ "16-49 employees", "FROM16TO49" ],
    [ "50-99 employees", "FROM50TO99" ],
    [ "100-249 employees", "FROM100TO249" ],
    [ "250-499 employees", "FROM250TO499" ],
    [ "500-999 employees", "FROM500TO999" ],
    [ "1000-4999 employees", "FROM1000TO4999" ],
    [ "5000-9999 employees", "FROM5000TO9999" ],
    [ "10,000 or more employees", "FROM10000" ]
  ]

  ID_TYPES = [
    [ "ACN", "ACN" ],
    [ "BN", "BN" ],
    [ "CN", "CN" ],
    [ "CPR", "CPR" ],
    [ "CVR", "CVR" ],
    [ "DIN", "DIN" ],
    [ "KT", "KT" ],
    [ "ORG", "ORG" ],
    [ "SEC", "SEC" ],
    [ "Other", "OTHER" ]
  ]

  COUNTRIES = [
    "Afghanistan", "Albania", "Algeria", "Andorra", "Angola", "Antigua and Barbuda", "Argentina",
    "Armenia", "Australia", "Austria", "Azerbaijan", "Bahamas", "Bahrain", "Bangladesh", "Barbados",
    "Belarus", "Belgium", "Belize", "Benin", "Bhutan", "Bolivia", "Bosnia and Herzegovina", "Botswana",
    "Brazil", "Brunei", "Bulgaria", "Burkina Faso", "Burundi", "Cabo Verde", "Cambodia", "Cameroon",
    "Canada", "Central African Republic", "Chad", "Chile", "China", "Colombia", "Comoros", "Congo (Congo-Brazzaville)",
    "Costa Rica", "Croatia", "Cuba", "Cyprus", "Czech Republic", "Democratic Republic of the Congo", "Denmark",
    "Djibouti", "Dominica", "Dominican Republic", "Ecuador", "Egypt", "El Salvador", "Equatorial Guinea",
    "Eritrea", "Estonia", "Eswatini", "Ethiopia", "Fiji", "Finland", "France", "Gabon", "Gambia", "Georgia",
    "Germany", "Ghana", "Greece", "Grenada", "Guatemala", "Guinea", "Guinea-Bissau", "Guyana", "Haiti",
    "Honduras", "Hungary", "Iceland", "India", "Indonesia", "Iran", "Iraq", "Ireland", "Israel", "Italy",
    "Ivory Coast", "Jamaica", "Japan", "Jordan", "Kazakhstan", "Kenya", "Kiribati", "Kuwait", "Kyrgyzstan",
    "Laos", "Latvia", "Lebanon", "Lesotho", "Liberia", "Libya", "Liechtenstein", "Lithuania", "Luxembourg",
    "Madagascar", "Malawi", "Malaysia", "Maldives", "Mali", "Malta", "Marshall Islands", "Mauritania",
    "Mauritius", "Mexico", "Micronesia", "Moldova", "Monaco", "Mongolia", "Montenegro", "Morocco", "Mozambique",
    "Myanmar (Burma)", "Namibia", "Nauru", "Nepal", "Netherlands", "New Zealand", "Nicaragua", "Niger",
    "Nigeria", "North Korea", "North Macedonia", "Norway", "Oman", "Pakistan", "Palau", "Palestine State",
    "Panama", "Papua New Guinea", "Paraguay", "Peru", "Philippines", "Poland", "Portugal", "Qatar", "Romania",
    "Russia", "Rwanda", "Saint Kitts and Nevis", "Saint Lucia", "Saint Vincent and the Grenadines", "Samoa",
    "San Marino", "Sao Tome and Principe", "Saudi Arabia", "Senegal", "Serbia", "Seychelles", "Sierra Leone",
    "Singapore", "Slovakia", "Slovenia", "Solomon Islands", "Somalia", "South Africa", "South Korea",
    "South Sudan", "Spain", "Sri Lanka", "Sudan", "Suriname", "Sweden", "Switzerland", "Syria", "Taiwan",
    "Tajikistan", "Tanzania", "Thailand", "Timor-Leste", "Togo", "Tonga", "Trinidad and Tobago", "Tunisia",
    "Turkey", "Turkmenistan", "Tuvalu", "Uganda", "Ukraine", "United Arab Emirates", "United Kingdom",
    "United States of America", "Uruguay", "Uzbekistan", "Vanuatu", "Vatican City", "Venezuela", "Vietnam",
    "Yemen", "Zambia", "Zimbabwe"
  ]
end
