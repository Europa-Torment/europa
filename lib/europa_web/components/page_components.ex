defmodule EuropaWeb.PageComponents do
  use EuropaWeb, :html
  use Gettext, backend: Europa.Gettext

  def timeline(assigns) do
    text_style = "text-md font-display tracking-wide"

    events =
      [
        {"~2050", gettext("The beginning of the crisis"),
         gettext("Earth's resources are nearing depletion. Wars are breaking out, including local nuclear conflicts.")},
        {"~2060", gettext("New Hope"),
         gettext(
           "People understand that the only way to preserve civilization is to colonize other celestial bodies. Research is underway into interplanetary travel and fusion reactors."
         )},
        {"~2100", gettext("First colonies"),
         gettext("The first groups of settlers began to settle on Mars and the satellites of Jupiter.")},
        {"2136", gettext("Terraforming Europa"),
         gettext(
           "A thermonuclear terraforming center has been built on Europa. Temperatures in some regions have approached 0 degrees Celsius. Water vapor has begun to form an atmosphere."
         )},
        {"2152", gettext("The Disaster"),
         gettext(
           "A man-made disaster occurred: the main thermonuclear reactor malfunctioned and exploded, releasing a monstrous amount of energy. The ice on the surface thinned, and monsters began to emerge from beneath it."
         )},
        {"2153", gettext("Left to die"),
         gettext(
           "The top brass and the wealthy fled Europa on the first prototypes of the 'generation ships', leaving the rest to certain death."
         )},
        {"2200", gettext("The end of human history"), gettext("The last known person in the solar system has died.")}
      ]
      |> Enum.with_index(fn event, index ->
        if rem(index, 2) == 0 do
          {event, "timeline-start mb-10 md:text-end #{text_style}"}
        else
          {event, "timeline-end md:mb-10 #{text_style}"}
        end
      end)

    assigns = assign(assigns, events: events)

    ~H"""
    <ul class="timeline timeline-snap-icon max-md:timeline-compact timeline-vertical">
      <%= for {{year, title, text}, class} <- @events do %>
        <li>
          <div class="timeline-middle">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              class="h-5 w-5"
            >
              <path
                fill-rule="evenodd"
                d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z"
                clip-rule="evenodd"
              />
            </svg>
          </div>
          <div class={class}>
            <time class="text-xl font-display font-bold text-cyan-100 tracking-wide mb-2">{year}</time>
            <div class="text-lg font-display text-cyan-300 tracking-wide mb-2">{title}</div>
            {text}
          </div>
          <hr />
        </li>
      <% end %>
    </ul>
    """
  end

  def organisations(assigns) do
    organisations = [
      {~p"/images/ETC.png", gettext("Europa Terraforming Center (ETC)"),
       gettext(
         "The power core of Europa. A small artificial sun. A chain of thermonuclear reactors that generate energy through hydrogen fusion and form an atmosphere. It was completely destroyed in the disaster."
       )},
      {~p"/images/WCC.png", gettext("Western Colonisation Community (WCC)"),
       gettext(
         "A political regulatory structure composed primarily of former Western leaders on Earth. It is widely believed that the leadership of this organization is to blame for the disaster. Instead of starting a new life, taking into account all their previous earthly mistakes, they continued to wield power and money for their own benefit."
       )},
      {~p"/images/SSB.png", gettext("Solar System Brotherhood (SSB)"),
       gettext(
         "An opposition rebel group. The main opponents of the WCC. Disparate armed terrorist groups whose goal is to disband the WCC and transfer control of Europa to its people."
       )}
    ]

    assigns = assign(assigns, organisations: organisations)

    ~H"""
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 md:gap-8 auto-rows-fr">
      <%= for {logo, name, description} <- @organisations do %>
        <div class="card bg-base-200 shadow-xl overflow-hidden border border-white/30 backdrop-blur-sm">
          <figure class="relative overflow-hidden">
            <img
              src={logo}
              class="w-full h-48 md:h-56 object-cover"
            />
          </figure>
          <div class="card-body p-5 md:p-6">
            <h2 class="card-title text-lg font-display text-cyan-300 tracking-wide mb-2 flex items-center gap-2">
              {name}
            </h2>
            <p class="text-xs font-display tracking-wide">
              {description}
            </p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def characters(assigns) do
    characters = [
      {gettext("Li Tian"),
       gettext(
         "Nuclear physicist. One of the first colonists, co-author of the first mass-produced thermonuclear reactor. Director of the Europa Terraforming Center."
       )},
      {gettext("Chen Yan"),
       gettext(
         "Nuclear physicist. Wife of Li Tian. She was his deputy and co-author of the fusion reactor. She died in the disaster because she was close to the epicenter of the explosion at the time."
       )},
      {gettext("Li Zhang"),
       gettext(
         "Son of Li Tian and Chen Yan. The first person born on Europa. The last person died in entire solar system."
       )},
      {gettext("Stanislav Mishchenko"),
       gettext(
         "Creator of the SSB. Rebel leader. The first known space terrorist. Believed to be responsible for the destruction of the Martian colony."
       )},
      {gettext("Henry Davies"),
       gettext(
         "Initially elected by the people of Earth as the main coordinator of colonization, he subsequently granted himself title of the President of WCC, which is essentially analogous to the President of all of Europa and human civilization. He survived several assassination attempts by the SSB, but to the surprise of many, he did not leave Europa after the disaster, although he had every opportunity."
       )}
    ]

    assigns = assign(assigns, characters: characters)

    ~H"""
    <ul>
      <%= for {name, bio} <- @characters do %>
        <li class="mb-10">
          <p class="text-md font-display text-cyan-300 mb-2">{name}</p>
          <span class="text-sm font-display tracking-wide">{bio}</span>
        </li>
      <% end %>
    </ul>
    """
  end
end
