xml.instruct! :xml, version: '1.0', encoding: 'UTF-8'
xml.urlset xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9' do
  @urls.each do |u|
    xml.url do
      xml.loc        u[:loc]
      xml.lastmod    u[:lastmod]    if u[:lastmod]
      xml.changefreq u[:changefreq] if u[:changefreq]
      xml.priority   u[:priority]   if u[:priority]
    end
  end
end
