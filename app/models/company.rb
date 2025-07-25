class Company < ApplicationRecord
  has_one_attached :profile_image
  belongs_to :user

  INDUSTRIES = [
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
end
