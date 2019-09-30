defmodule Full do

  use GenServer


  # DECISION:  GOSSIP vs PUSH_SUM
  def init([x,n, is_push_sum]) do
    case is_push_sum do
      0 -> {:ok, [Active,0,0, n, x ] } #[ rec_count, sent_count, n, self_number_id | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, n, x] } #[ rec_count,streak,prev_s_w,to_terminate, s, w, n, self_number_id | neighbors ]
    end
  end

    # GOSSIP - RECIEVE Main
  def handle_cast({:message_gossip, _received}, [status,count,sent,n,x ] =state ) do
    length = round(Float.ceil(:math.sqrt(n)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    case count < 100 do
      true ->  GenServer.cast(Master,{:received, [{i,j}]})
               gossip(x,self(),n,i,j)
      false -> GenServer.cast(Master,{:hibernated, [{i,j}]})
    end
    {:noreply,[status,count+1 ,sent,n, x  ]}
  end

  # GOSSIP  - SEND Main
  def gossip(x,pid, n,i,j) do
    the_one = the_chosen_one(n)
    case the_one == droid_name(x) do
      true -> gossip(x,pid, n,i,j)
      false ->
        GenServer.cast(the_one, {:message_gossip, :_sending})
        # ina_xy -> GenServer.cast(Master,{:droid_inactive, ina_xy})
        #gossip(x,pid, n,i,j)
        # case GenServer.call(the_one,:is_active) do
        #   Active -> GenServer.cast(the_one, {:message_gossip, :_sending})
        #             ina_xy -> GenServer.cast(Master,{:droid_inactive, ina_xy})
        #             gossip(x,pid, n,i,j)
        # end
      end
  end

    # NETWORK : Creating Network
  def create_network(n, is_push_sum \\ 0) do
    droids =
      for x <- 1..n do
        name = droid_name(x)
        GenServer.start_link(Full, [x,n,is_push_sum], name: name)
        name
      end
    GenServer.cast(Master,{:droids_update,droids})
  end

  # NETWORK : Naming the node
  def droid_name(x) do
    a = x|> Integer.to_string |> String.pad_leading(7,"0")
    "Elixir.D"<>a
    |>String.to_atom
  end

  # NETWORK : Defining and assigning Neighbors
  # ~ Not required as all are neighbors

  # NETWORK : Choosing a neigbor randomly to send message to
  def the_chosen_one(n) do
    :rand.uniform(n)
    |> droid_name()
  end

end
