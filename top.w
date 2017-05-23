@* Top-level Functions.

Broadly speaking, the top-level functions are in charge of computing
samples for the DSP inner-loop before, after, and during runtime. They get their
name from the fact that they are the top level of abstraction in the program.
These are the functions that get called in the Sporth Unit Generator 
implementation |@<The Sporth Unit...@>|. 


@<Top Level Functions@>=
@<Voc Create@>@/
@<Voc Destroy@>@/
@<Voc Init...@>@/
@<Voc Compute@>@/
@<Voc Set Frequency@>@/
@<Voc Get Tract Diameters@>@/
@<Voc Get Tract Size@>@/
@<Voc Get Nose Diameters@>@/
@<Voc Get Nose Size@>@/
@<Voc Set Diameters@>@/
@<Voc Set Tongue Shape@>@/
@<Voc Get Counter@>@/
@<Voc Set Breathiness@>@/

@ @<Voc Create@>=
int sp_voc_create(sp_voc **voc)
{
    *voc = malloc(sizeof(sp_voc));
    return SP_OK;
}

@ @<Voc Destroy@>=
int sp_voc_destroy(sp_voc **voc)
{
    free(*voc);
    return SP_OK;
}

@ @<Voc Initialization@>=
int sp_voc_init(sp_data *sp, sp_voc *voc)
{
    glottis_init(&voc->glot, sp->sr); /* initialize glottis */
    tract_init(sp, &voc->tr); /* initialize vocal tract */
    voc->counter = 0;
    return SP_OK;
}

@ @<Voc Compute@>=
int sp_voc_compute(sp_data *sp, sp_voc *voc, SPFLOAT *out)
{
    SPFLOAT vocal_output, glot;
    SPFLOAT lambda1, lambda2;
    int i;

    @q vocal_output = 0; @>
   
    if(voc->counter == 0) {
        tract_reshape(&voc->tr); 
        tract_calculate_reflections(&voc->tr); 
        for(i = 0; i < 512; i++) {
            vocal_output = 0;
            lambda1 = (SPFLOAT) i / 512;
            lambda2 = (SPFLOAT) (i + 0.5) / 512;
            glot = glottis_compute(sp, &voc->glot, lambda1);
           
            tract_compute(sp, &voc->tr, glot, lambda1);
            vocal_output += voc->tr.lip_output + voc->tr.nose_output;

            tract_compute(sp, &voc->tr, glot, lambda2);
            vocal_output += voc->tr.lip_output + voc->tr.nose_output;
            voc->buf[i] = vocal_output * 0.125;
        }
    }


    *out = voc->buf[voc->counter];
    voc->counter = (voc->counter + 1) % 512;
    return SP_OK;
}

@ The function |sp_voc_set_frequency| sets the fundamental frequency
for the glottal wave.

@<Voc Set Frequency@> =
void sp_voc_set_frequency(sp_voc *voc, SPFLOAT freq)
{
    voc->glot.freq = freq;
}

@ This getter function returns the cylindrical diameters representing 
tract. 

@<Voc Get Tract Diameters@>=
SPFLOAT* sp_voc_get_tract_diameters(sp_voc *voc)
{
    return voc->tr.target_diameter;
}

@ This getter function returns the size of the vocal tract. 
@<Voc Get Tract Size@>=
int sp_voc_get_tract_size(sp_voc *voc)
{
    return voc->tr.n;
}

@ This function returns the cylindrical diameters of the nasal cavity.
@<Voc Get Nose Diameters@>=

SPFLOAT* sp_voc_get_nose_diameters(sp_voc *voc)
{
    return voc->tr.nose_diameter;
}

@ This function returns the nose size.
@<Voc Get Nose Size@>=
int sp_voc_get_nose_size(sp_voc *voc)
{
    return voc->tr.nose_length;
}

@ The function |sp_voc_set_diameter()| is a function adopted from Neil Thapen's
Pink Trombone in a function he called setRestDiameter. It is the main function
in charge of the "tongue position" XY control. Modifications to the original
function have been made in an attempt to make the function more generalized.
Instead of relying on internal state, all variables used are parameters in
the function. Because of this fact, there are quite a few function
parameters:

\item{$\bullet$} {\bf voc}, the core Voc data struct 
\item{$\bullet$} {\bf blade\_start}, index where the blade (?) starts. 
this is set to 10 in pink trombone
\item{$\bullet$} {\bf lip\_start}, index where lip starts. this constant is 
set to 39.
\item{$\bullet$} {\bf tip\_start}, this is set to 32.
\item{$\bullet$} {\bf tongue\_index} 
\item{$\bullet$} {\bf tongue\_diameter}
\item{$\bullet$} {\bf diameters}, the floating point array to write to 

For practical use cases, it is not ideal to call this function directly.
Instead, it can be indirectly called using a more sane function 
|sp_voc_set_tongue_shape()|, found in the section |@<Voc Set Tongue Shape@>|.

@<Voc Set Diameters@>=
void sp_voc_set_diameters(sp_voc *voc, @/
    int blade_start, @/
    int lip_start, @/
    int tip_start, @/
    SPFLOAT tongue_index,@/
    SPFLOAT tongue_diameter, @/
    SPFLOAT *diameters) {

    int i;
    SPFLOAT t;
    SPFLOAT fixed_tongue_diameter;
    SPFLOAT curve;
    int grid_offset = 0;

    for(i = blade_start; i < lip_start; i++) {
        t = 1.1 * M_PI * 
            (SPFLOAT)(tongue_index - i)/(tip_start - blade_start);
        fixed_tongue_diameter = 2+(tongue_diameter-2)/1.5;
        curve = (1.5 - fixed_tongue_diameter + grid_offset) * cos(t);
        if(i == blade_start - 2 || i == lip_start - 1) curve *= 0.8;
        if(i == blade_start || i == lip_start - 2) curve *= 0.94;
        diameters[i] = 1.5 - curve;
    }
}


@ The function |sp_voc_set_tongue_shape()| will set the shape of the 
tongue using the two primary arguments |tongue_index| and |tongue_diameter|.
It is a wrapper around the function described in |@<Voc Set Diameters@>|, 
filling in the constants used, and thereby making it simpler to work with.

A few tract shapes shaped using this function have been generated below:

\displayfig{plots/tongueshape1.eps}

\displayfig{plots/tongueshape2.eps}

\displayfig{plots/tongueshape3.eps}

@<Voc Set Tongue Shape@>=

void sp_voc_set_tongue_shape(sp_voc *voc, 
    SPFLOAT tongue_index, @/
    SPFLOAT tongue_diameter) {
    SPFLOAT *diameters;
    diameters = sp_voc_get_tract_diameters(voc);
    sp_voc_set_diameters(voc, 10, 39, 32, 
            tongue_index, tongue_diameter, diameters);
}

@ Voc keeps an internal counter for control rate operations called inside
of the audio-rate compute function in |@<Voc Compute@>|. The function 
|sp_voc_get_counter()| gets the current counter position. When the counter
is 0, the next call to |sp_voc_compute| will compute another block of audio.
Getting the counter position before the call allows control-rate variables
to be set before then.

@<Voc Get Counter@>=

int sp_voc_get_counter(sp_voc *voc)
{
    return voc->counter;
}
@
@<Voc Set Breathiness@>=
int sp_voc_set_breathiness(sp_voc *voc, SPFLOAT breathiness)
{
    voc->glot.tenseness = breathiness;
}
