module ShowRackSections

using CairoMakie, CUFSM, CrossSectionFigures, ShowCUFSM


function step_beam(section, api_figure_options)  #can be used for regular step beams, angled step beams 


    all_figures = []

    t = section.input.t

    #gross section 
    # drawing_scale = 1.0
    # line_color = :grey
    # line_color = options.line_color
    x = section.geometry.x
    y = section.geometry.y
    num_elem = length(x)
    t_all = fill(t, num_elem)

    Δ = get_drawing_extents(x, y, t)   
    drawing_size, thickness_scale = define_drawing_size(Δ, api_figure_options.max_pixel_size)

    backgroundcolor=:transparent
    # linecolor = :grey
    linecolor = Symbol(api_figure_options.cross_section_linecolor)
    joinstyle=:round
    linecap=:flat
    hidedecorations = true
    hidespines = true

    options = CrossSectionFigures.SectionOptions(drawing_size, thickness_scale, backgroundcolor, linecolor, joinstyle, linecap, hidedecorations, hidespines)

    figure = CrossSectionFigures.section(x, y, t_all, options)
    push!(all_figures, figure)
    
    #local buckling P signature curve 
    model = section.local_buckling_P
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = t_all
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    #local buckling Mxx_pos signature curve 
    model = section.local_buckling_Mxx_pos
    all_figures = signature_curve(model, all_figures, api_figure_options)
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    #local buckling Mxx_neg signature curve 
    model = section.local_buckling_Mxx_neg
    all_figures = signature_curve(model, all_figures, api_figure_options)
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)




    #local buckling Myy_pos signature curve 
    model = section.local_buckling_Myy_pos
    all_figures = signature_curve(model, all_figures, api_figure_options)
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)

    #local buckling Myy_neg signature curve 
    model = section.local_buckling_Myy_neg
    all_figures = signature_curve(model, all_figures, api_figure_options)
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    all_figures_IO = Vector{UInt8}[]
    for i in eachindex(all_figures)

        io = IOBuffer()
        show(io, MIME"image/png"(), all_figures[i])
        push!(all_figures_IO, io.data)

    end

    figure_labels = ["gross_section", "local_buckling_P_signature_curve", "local_buckling_P_mode_shape", "local_buckling_Mxx_pos_signature_curve", "local_buckling_Mxx_pos_mode_shape", "local_buckling_Mxx_neg_signature_curve", "local_buckling_Mxx_neg_mode_shape", "local buckling Myy_pos_signature_curve", "local_buckling_Myy_pos_mode_shape", "local_buckling_Myy_neg_signature_curve", "local_buckling_Myy_neg_mode_shape"]

    return all_figures_IO, all_figures, figure_labels

end


function get_drawing_extents(x, y, t)

    ΔX = abs(maximum(x) - minimum(x)) + maximum(t)
    ΔY = abs(maximum(y) - minimum(y)) + maximum(t)

    Δ = [ΔX, ΔY]

    return Δ

end



function define_drawing_size(Δ, max_pixel_size)

    max_index = argmax(Δ)
    min_index = argmin(Δ)

    if max_index == min_index
        min_index = 2
    end

    drawing_size = Vector{Float64}(undef, 2)
    
    # drawing_size[max_index] = 2048.0
    # drawing_size[min_index] = 2048.0 * Δ[min_index] / Δ[max_index]

    # thickness_scale = (2048.0 / Δ[max_index])

    drawing_size[max_index] = max_pixel_size
    drawing_size[min_index] = max_pixel_size * Δ[min_index] / Δ[max_index]

    thickness_scale = (max_pixel_size / Δ[max_index])

    return drawing_size, thickness_scale

end


function get_deformed_shape_extents(model, eig, deformation_scale)

        
    Pcr = CUFSM.Tools.get_load_factor(model, eig)
    mode_index = argmin(Pcr)
    mode = model.shapes[mode_index][:, eig]
    t = model.elem[:, 4]
    n = fill(5, length(t))
    cross_section_coords, Δ_nodes, figure_max_dim_range = ShowCUFSM.cross_section_mode_shape_info(model.elem, model.node, mode, n, deformation_scale)

    return figure_max_dim_range

end


function signature_curve(model, all_figures, api_figure_options)

    eig = 1
    backgroundcolor = :transparent
    linecolor = Symbol(api_figure_options.signature_curve_linecolor)
    linewidth = 1 * 3.5
    fontsize = 12 * 3.5
    markersize = 6 * 3.5 
    drawing_size = [api_figure_options.max_pixel_size, api_figure_options.max_pixel_size] 


    options = ShowCUFSM.SignatureCurveOptions(drawing_size, backgroundcolor, linecolor, linewidth, fontsize, markersize)

    ax, figure = ShowCUFSM.signature_curve(model, eig, options)
    push!(all_figures, figure)

    all_figures

end


function mode_shape(model, t, t_elements, all_figures, api_figure_options)
    
    deformation_scale = (0.5, 0.5)
    eig = 1

    Δ = get_deformed_shape_extents(model, eig, deformation_scale) .+ t

    drawing_size, thickness_scale = define_drawing_size(Δ, api_figure_options.max_pixel_size)

    backgroundcolor = :transparent
    linecolor = Symbol(api_figure_options.cross_section_linecolor)
    linestyle = :solid 
    joinstyle = :miter
    
    options = ShowCUFSM.ModeShapeOptions(drawing_size, thickness_scale, backgroundcolor, linecolor, linestyle, joinstyle)

    ax, figure = ShowCUFSM.minimum_mode_shape(model, eig, t_elements, deformation_scale, options)
    push!(all_figures, figure)

    return all_figures

end


function closed_tube_column(section, api_figure_options)  


    all_figures = []

    t = section.input.t

    x = section.geometry.x
    y = section.geometry.y

    # #out to out range of cross-section
    # ΔX = abs(maximum(x) - minimum(x)) + maximum(t)
    # ΔY = abs(maximum(y) - minimum(y)) + maximum(t)

    # Δ = [ΔX, ΔY]
    # max_index = argmax(Δ)
    # min_index = argmin(Δ)

    # if max_index == min_index
    #     min_index = 2
    # end

    # drawing_size = Vector{Float64}(undef, 2)
    
    # drawing_size[max_index] = 2048.0
    # drawing_size[min_index] = 2048.0 * Δ[min_index] / Δ[max_index]

    # thickness_scale = (2048.0 / Δ[max_index])

    Δ = get_drawing_extents(x, y, t)   
    drawing_size, thickness_scale = define_drawing_size(Δ, api_figure_options.max_pixel_size)

    backgroundcolor=:transparent
    linecolor = :grey
    joinstyle=:round
    linecap=:flat
    hidedecorations = true
    hidespines = true


    options = CrossSectionFigures.SectionOptions(drawing_size, thickness_scale, backgroundcolor, linecolor, joinstyle, linecap, hidedecorations, hidespines)

    
    #gross section 

    num_elem = length(x)
    t_all = fill(t, num_elem)
    figure = CrossSectionFigures.section(x, y, t_all, options)
    push!(all_figures, figure)

    #net section 
    # x = section.geometry.x
    # y = section.geometry.y

    num_elem = length(x)
    t_all = section.tg
    figure = CrossSectionFigures.section(x, y, t_all, options)
    push!(all_figures, figure)


    #local buckling, P 
    model = section.local_buckling_P
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.tg
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)

 
    #local buckling, Mxx 
    model = section.local_buckling_Mxx
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.tg
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    #local buckling, Myy_pos 
    model = section.local_buckling_Myy_pos
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.tg
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    #local buckling, Myy_neg
    model = section.local_buckling_Myy_neg
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.tg
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)




    all_figures_IO = Vector{UInt8}[]
    for i in eachindex(all_figures)

        io = IOBuffer()
        show(io, MIME"image/png"(), all_figures[i])
        push!(all_figures_IO, io.data)

    end
   

    figure_labels = ["gross_section", "net section", "local_buckling_P_signature_curve", "local_buckling_P_mode_shape", "local_buckling_Mxx_pos_signature_curve", "local_buckling_Mxx_pos_mode_shape", "local_buckling_Mxx_neg_signature_curve", "local_buckling_Mxx_neg_mode_shape", "local buckling Myy_pos_signature_curve", "local_buckling_Myy_pos_mode_shape", "local_buckling_Myy_neg_signature_curve", "local_buckling_Myy_neg_mode_shape"]

    return all_figures_IO, all_figures, figure_labels


end


function cee_with_lips_column(section, api_figure_options)  


    all_figures = []

    t = section.input.t

    x = section.geometry.x
    y = section.geometry.y

    Δ = get_drawing_extents(x, y, t)   
    drawing_size, thickness_scale = define_drawing_size(Δ, api_figure_options.max_pixel_size)

    backgroundcolor=:transparent
    linecolor = :grey
    joinstyle=:round
    linecap=:flat
    hidedecorations = true
    hidespines = true


    options = CrossSectionFigures.SectionOptions(drawing_size, thickness_scale, backgroundcolor, linecolor, joinstyle, linecap, hidedecorations, hidespines)

    
    #gross section 

    num_elem = length(x) - 1
    t_all = fill(t, num_elem)
    figure = CrossSectionFigures.section(x, y, t_all, options)
    push!(all_figures, figure)

    #net section
    t_all = section.tg
    figure = CrossSectionFigures.section(x, y, t_all, options)
    push!(all_figures, figure)


    #local buckling, P 
    model = section.local_buckling_P
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.tg
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    #distortional buckling, P 
    model = section.distortional_buckling_P
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.td
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


 
    #local buckling, Mxx 
    model = section.local_buckling_Mxx
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.tg
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)

    #distortional buckling, Mxx 
    model = section.distortional_buckling_Mxx
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.td
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)



    #local buckling, Myy_pos 
    model = section.local_buckling_Myy_pos
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.tg
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    #local buckling, Myy_neg
    model = section.local_buckling_Myy_neg
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.tg
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)




    all_figures_IO = Vector{UInt8}[]
    for i in eachindex(all_figures)

        io = IOBuffer()
        show(io, MIME"image/png"(), all_figures[i])
        push!(all_figures_IO, io.data)

    end
   

    figure_labels = ["gross_section", "net section", "local_buckling_P_signature_curve", "local_buckling_P_mode_shape", "distortional_buckling_P_signature_curve", "distortional_buckling_P_mode_shape", "local_buckling_Mxx_signature_curve", "local_buckling_Mxx_mode_shape", "distortional_buckling_Mxx_signature_curve", "distortional_buckling_Mxx_mode_shape", "local buckling Myy_pos_signature_curve", "local_buckling_Myy_pos_mode_shape", "local_buckling_Myy_neg_signature_curve", "local_buckling_Myy_neg_mode_shape"]

    return all_figures_IO, all_figures, figure_labels


end




function hat_with_rib_column(section, api_figure_options)  


    all_figures = []

    t = section.input.t

    x = section.geometry.x
    y = section.geometry.y

    Δ = get_drawing_extents(x, y, t)   
    drawing_size, thickness_scale = define_drawing_size(Δ, api_figure_options.max_pixel_size)

    backgroundcolor=:transparent
    linecolor = :grey
    joinstyle=:miter
    linecap=:butt
    hidedecorations = true
    hidespines = true


    options = CrossSectionFigures.SectionOptions(drawing_size, thickness_scale, backgroundcolor, linecolor, joinstyle, linecap, hidedecorations, hidespines)

    
    #gross section 

    num_elem = length(x) - 1
    t_all = fill(t, num_elem)
    figure = CrossSectionFigures.section(x, y, t_all, options)
    push!(all_figures, figure)

    #net section
    t_all = section.tg
    figure = CrossSectionFigures.section(x, y, t_all, options)
    push!(all_figures, figure)


    #local buckling, P 
    model = section.local_buckling_P
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.tg
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    #distortional buckling, P 
    model = section.distortional_buckling_P
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.td
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


 
    #local buckling, Mxx 
    model = section.local_buckling_Mxx
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.tg
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)

    #distortional buckling, Mxx 
    model = section.distortional_buckling_Mxx
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.td
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)



    #distortional buckling, Myy_pos 
    model = section.distortional_buckling_Myy_pos
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.td
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    #local buckling, Myy_neg
    model = section.local_buckling_Myy_neg
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.tg
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)




    all_figures_IO = Vector{UInt8}[]
    for i in eachindex(all_figures)

        io = IOBuffer()
        show(io, MIME"image/png"(), all_figures[i])
        push!(all_figures_IO, io.data)

    end
   

    figure_labels = ["gross_section", "net section", "local_buckling_P_signature_curve", "local_buckling_P_mode_shape", "distortional_buckling_P_signature_curve", "distortional_buckling_P_mode_shape", "local_buckling_Mxx_signature_curve", "local_buckling_Mxx_mode_shape", "distortional_buckling_Mxx_signature_curve", "distortional_buckling_Mxx_mode_shape", "distortional buckling Myy_pos_signature_curve", "distortional_buckling_Myy_pos_mode_shape", "local_buckling_Myy_neg_signature_curve", "local_buckling_Myy_neg_mode_shape"]

    return all_figures_IO, all_figures, figure_labels


end





function unistrut_in_column(section, api_figure_options)  


    all_figures = []

    t = section.input.t

    x = section.geometry.x
    y = section.geometry.y

    Δ = get_drawing_extents(x, y, t)   
    drawing_size, thickness_scale = define_drawing_size(Δ, api_figure_options.max_pixel_size)

    backgroundcolor=:transparent
    linecolor = :grey
    joinstyle=:round
    linecap=:flat
    hidedecorations = true
    hidespines = true


    options = CrossSectionFigures.SectionOptions(drawing_size, thickness_scale, backgroundcolor, linecolor, joinstyle, linecap, hidedecorations, hidespines)

    
    #gross section 

    num_elem = length(x) - 1
    t_all = fill(t, num_elem)
    figure = CrossSectionFigures.section(x, y, t_all, options)
    push!(all_figures, figure)

    #net section
    t_all = section.tg
    figure = CrossSectionFigures.section(x, y, t_all, options)
    push!(all_figures, figure)


    #local buckling, P 
    model = section.local_buckling_P
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.tg
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    #distortional buckling, P 
    model = section.distortional_buckling_P
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.td
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


 
    #local buckling, Mxx 
    model = section.local_buckling_Mxx
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.tg
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)

    #distortional buckling, Mxx 
    model = section.distortional_buckling_Mxx
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.td
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)



    #local buckling, Myy_pos 
    model = section.local_buckling_Myy_pos
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.td
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    #local buckling, Myy_neg
    model = section.local_buckling_Myy_neg
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.tg
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)




    all_figures_IO = Vector{UInt8}[]
    for i in eachindex(all_figures)

        io = IOBuffer()
        show(io, MIME"image/png"(), all_figures[i])
        push!(all_figures_IO, io.data)

    end
   

    figure_labels = ["gross_section", "net section", "local_buckling_P_signature_curve", "local_buckling_P_mode_shape", "distortional_buckling_P_signature_curve", "distortional_buckling_P_mode_shape", "local_buckling_Mxx_signature_curve", "local_buckling_Mxx_mode_shape", "distortional_buckling_Mxx_signature_curve", "distortional_buckling_Mxx_mode_shape", "local buckling Myy_pos_signature_curve", "local_buckling_Myy_pos_mode_shape", "local_buckling_Myy_neg_signature_curve", "local_buckling_Myy_neg_mode_shape"]

    return all_figures_IO, all_figures, figure_labels


end



function unistrut_out_column(section, api_figure_options)  


    all_figures = []

    t = section.input.t

    x = section.geometry.x
    y = section.geometry.y

    Δ = get_drawing_extents(x, y, t)   
    drawing_size, thickness_scale = define_drawing_size(Δ, api_figure_options.max_pixel_size)

    backgroundcolor=:transparent
    linecolor = :grey
    joinstyle=:round
    linecap=:flat
    hidedecorations = true
    hidespines = true


    options = CrossSectionFigures.SectionOptions(drawing_size, thickness_scale, backgroundcolor, linecolor, joinstyle, linecap, hidedecorations, hidespines)

    
    #gross section 

    num_elem = length(x) - 1
    t_all = fill(t, num_elem)
    figure = CrossSectionFigures.section(x, y, t_all, options)
    push!(all_figures, figure)

    #net section
    t_all = section.tg
    figure = CrossSectionFigures.section(x, y, t_all, options)
    push!(all_figures, figure)


    #local buckling, P 
    model = section.local_buckling_P
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.tg
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    # #distortional buckling, P 
    # model = section.distortional_buckling_P
    # all_figures = signature_curve(model, all_figures, api_figure_options)

    # t_elements = section.td
    # all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


 
    #local buckling, Mxx 
    model = section.local_buckling_Mxx
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.tg
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)

    # #distortional buckling, Mxx 
    # model = section.distortional_buckling_Mxx
    # all_figures = signature_curve(model, all_figures, api_figure_options)

    # t_elements = section.td
    # all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)



    #local buckling, Myy_pos 
    model = section.local_buckling_Myy_pos
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.tg
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    #local buckling, Myy_neg
    model = section.local_buckling_Myy_neg
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = section.tg
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)




    all_figures_IO = Vector{UInt8}[]
    for i in eachindex(all_figures)

        io = IOBuffer()
        show(io, MIME"image/png"(), all_figures[i])
        push!(all_figures_IO, io.data)

    end
   

    figure_labels = ["gross_section", "net section", "local_buckling_P_signature_curve", "local_buckling_P_mode_shape", "local_buckling_Mxx_signature_curve", "local_buckling_Mxx_mode_shape", "local buckling Myy_pos_signature_curve", "local_buckling_Myy_pos_mode_shape", "local_buckling_Myy_neg_signature_curve", "local_buckling_Myy_neg_mode_shape"]

    return all_figures_IO, all_figures, figure_labels


end




function cee_with_lips_brace(section, api_figure_options)  


    all_figures = []

    t = section.input.t

    x = section.geometry.x
    y = section.geometry.y

    Δ = get_drawing_extents(x, y, t)   
    drawing_size, thickness_scale = define_drawing_size(Δ, api_figure_options.max_pixel_size)

    backgroundcolor=:transparent
    linecolor = Symbol(api_figure_options.cross_section_linecolor)
    joinstyle=:round
    linecap=:flat
    hidedecorations = true
    hidespines = true


    options = CrossSectionFigures.SectionOptions(drawing_size, thickness_scale, backgroundcolor, linecolor, joinstyle, linecap, hidedecorations, hidespines)

    
    #gross section 

    num_elem = length(x) - 1
    t_all = fill(t, num_elem)
    figure = CrossSectionFigures.section(x, y, t_all, options)
    push!(all_figures, figure)


    #local buckling, P 
    model = section.local_buckling_P
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = t_all
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    #distortional buckling, P 
    model = section.distortional_buckling_P
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = t_all
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    all_figures_IO = Vector{UInt8}[]
    for i in eachindex(all_figures)

        io = IOBuffer()
        show(io, MIME"image/png"(), all_figures[i])
        push!(all_figures_IO, io.data)

    end
   

    figure_labels = ["gross_section", "local_buckling_P_signature_curve", "local_buckling_P_mode_shape", "distortional_buckling_P_signature_curve", "distortional_buckling_P_mode_shape"]

    return all_figures_IO, all_figures, figure_labels


end



function cee_brace(section, api_figure_options)  


    all_figures = []

    t = section.input.t

    x = section.geometry.x
    y = section.geometry.y

    Δ = get_drawing_extents(x, y, t)   
    drawing_size, thickness_scale = define_drawing_size(Δ, api_figure_options.max_pixel_size)

    backgroundcolor=:transparent
    linecolor = Symbol(api_figure_options.cross_section_linecolor)
    joinstyle=:round
    linecap=:flat
    hidedecorations = true
    hidespines = true


    options = CrossSectionFigures.SectionOptions(drawing_size, thickness_scale, backgroundcolor, linecolor, joinstyle, linecap, hidedecorations, hidespines)

    
    #gross section 

    num_elem = length(x) - 1
    t_all = fill(t, num_elem)
    figure = CrossSectionFigures.section(x, y, t_all, options)
    push!(all_figures, figure)


    #local buckling, P 
    model = section.local_buckling_P
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = t_all
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    all_figures_IO = Vector{UInt8}[]
    for i in eachindex(all_figures)

        io = IOBuffer()
        show(io, MIME"image/png"(), all_figures[i])
        push!(all_figures_IO, io.data)

    end
   

    figure_labels = ["gross_section", "local_buckling_P_signature_curve", "local_buckling_P_mode_shape"]

    return all_figures_IO, all_figures, figure_labels


end




function pipe_brace(section, api_figure_options)  


    all_figures = []

    t = section.input.t

    x = section.geometry.x
    y = section.geometry.y

    Δ = get_drawing_extents(x, y, t)   
    drawing_size, thickness_scale = define_drawing_size(Δ, api_figure_options.max_pixel_size)

    backgroundcolor=:transparent
    linecolor = :grey
    joinstyle=:round
    linecap=:flat
    hidedecorations = true
    hidespines = true


    options = CrossSectionFigures.SectionOptions(drawing_size, thickness_scale, backgroundcolor, linecolor, joinstyle, linecap, hidedecorations, hidespines)

    
    #gross section 

    num_elem = length(x)
    t_all = fill(t, num_elem)
    figure = CrossSectionFigures.section(x, y, t_all, options)
    push!(all_figures, figure)


    #local buckling, P 
    model = section.local_buckling_P
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = t_all
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    all_figures_IO = Vector{UInt8}[]
    for i in eachindex(all_figures)

        io = IOBuffer()
        show(io, MIME"image/png"(), all_figures[i])
        push!(all_figures_IO, io.data)

    end
   

    figure_labels = ["gross_section", "local_buckling_P_signature_curve", "local_buckling_P_mode_shape"]

    return all_figures_IO, all_figures, figure_labels


end




function rectangular_tube_brace(section, api_figure_options)  


    all_figures = []

    t = section.input.t

    x = section.geometry.x
    y = section.geometry.y

    Δ = get_drawing_extents(x, y, t)   
    drawing_size, thickness_scale = define_drawing_size(Δ, api_figure_options.max_pixel_size)

    backgroundcolor=:transparent
    linecolor = :grey
    joinstyle=:round
    linecap=:flat
    hidedecorations = true
    hidespines = true


    options = CrossSectionFigures.SectionOptions(drawing_size, thickness_scale, backgroundcolor, linecolor, joinstyle, linecap, hidedecorations, hidespines)

    
    #gross section 

    num_elem = length(x)
    t_all = fill(t, num_elem)
    figure = CrossSectionFigures.section(x, y, t_all, options)
    push!(all_figures, figure)


    #local buckling, P 
    model = section.local_buckling_P
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = t_all
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    all_figures_IO = Vector{UInt8}[]
    for i in eachindex(all_figures)

        io = IOBuffer()
        show(io, MIME"image/png"(), all_figures[i])
        push!(all_figures_IO, io.data)

    end
   

    figure_labels = ["gross_section", "local_buckling_P_signature_curve", "local_buckling_P_mode_shape"]

    return all_figures_IO, all_figures, figure_labels


end




function angle_brace(section, api_figure_options)  


    all_figures = []

    t = section.input.t

    x = section.geometry.x
    y = section.geometry.y

    Δ = get_drawing_extents(x, y, t)   
    drawing_size, thickness_scale = define_drawing_size(Δ, api_figure_options.max_pixel_size)

    backgroundcolor=:transparent
    linecolor = :grey
    joinstyle=:round
    linecap=:flat
    hidedecorations = true
    hidespines = true


    options = CrossSectionFigures.SectionOptions(drawing_size, thickness_scale, backgroundcolor, linecolor, joinstyle, linecap, hidedecorations, hidespines)

    
    #gross section 

    num_elem = length(x)-1
    t_all = fill(t, num_elem)
    figure = CrossSectionFigures.section(x, y, t_all, options)
    push!(all_figures, figure)


    #local buckling, P 
    model = section.local_buckling_P
    all_figures = signature_curve(model, all_figures, api_figure_options)

    t_elements = t_all
    all_figures = mode_shape(model, t, t_elements, all_figures, api_figure_options)


    all_figures_IO = Vector{UInt8}[]
    for i in eachindex(all_figures)

        io = IOBuffer()
        show(io, MIME"image/png"(), all_figures[i])
        push!(all_figures_IO, io.data)

    end
   

    figure_labels = ["gross_section", "local_buckling_P_signature_curve", "local_buckling_P_mode_shape"]

    return all_figures_IO, all_figures, figure_labels


end


end # module ShowRackSections
